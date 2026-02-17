local M = {}
local config = require('vayai.config')

-- Job handle for cancellation
local current_job = nil

-- Parse SSE (Server-Sent Events) data line
local function parse_sse_line(line)
  -- SSE format: "data: {...}"
  if line:match("^data: ") then
    local json_str = line:sub(7) -- Remove "data: " prefix
    
    -- Check for [DONE] signal
    if json_str == "[DONE]" then
      return nil, true -- Return done signal
    end
    
    -- Try to parse JSON
    local ok, data = pcall(vim.fn.json_decode, json_str)
    if ok then
      return data, false
    end
  end
  return nil, false
end

-- Ask model a question with streaming support
function M.ask_model(model_name, question, callback, system_prompt, stream_callback)
  local opts = config.options
  
  -- Use provided system prompt or default
  system_prompt = system_prompt or opts.system_prompts.default
  
  -- Determine if we should stream
  local should_stream = opts.stream and stream_callback ~= nil
  
  -- Prepare payload
  local payload = {
    model = model_name,
    messages = {
      { role = "system", content = system_prompt },
      { role = "user", content = question }
    },
    temperature = opts.temperature,
    max_tokens = opts.max_tokens,
    stream = should_stream
  }
  
  -- Prepare headers
  local headers = {
    "Authorization: Bearer " .. opts.api_key,
    "Content-Type: application/json"
  }
  
  -- Expand CA bundle path
  local ca_bundle = vim.fn.expand(opts.ca_bundle_path)
  
  -- Convert payload to JSON
  local json_payload = vim.fn.json_encode(payload)
  
  -- Prepare curl command
  local url = opts.api_base .. "/api/chat/completions"
  local cmd = {
    "curl",
    "-N", -- Disable buffering for streaming
    "-s",
    "-X", "POST",
    url,
    "--cacert", ca_bundle,
    "--max-time", tostring(opts.timeout),
    "-H", headers[1],
    "-H", headers[2],
    "-d", json_payload
  }
  
  if should_stream then
    -- Streaming mode
    local accumulated_response = ""
    local buffer = "" -- Buffer for incomplete lines
    
    local job_opts = {
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= "" then
              buffer = buffer .. line
              
              -- Check if we have complete lines (SSE messages end with double newline)
              -- But curl gives us line by line, so process each line
              local parsed_data, is_done = parse_sse_line(buffer)
              
              if is_done then
                -- Stream finished
                return
              end
              
              if parsed_data and parsed_data.choices and parsed_data.choices[1] then
                local delta = parsed_data.choices[1].delta
                if delta and delta.content then
                  local content = delta.content
                  accumulated_response = accumulated_response .. content
                  
                  -- Call stream callback with the delta
                  vim.schedule(function()
                    stream_callback(content, accumulated_response)
                  end)
                end
              end
              
              buffer = "" -- Reset buffer after processing
            end
          end
        end
      end,
      on_stderr = function(_, data)
        -- Handle any errors
        if data then
          for _, line in ipairs(data) do
            if line ~= "" then
              vim.schedule(function()
                -- Silently ignore curl progress messages
                if not line:match("^%s*$") and not line:match("^  %% Total") then
                  -- Only report actual errors
                end
              end)
            end
          end
        end
      end,
      on_exit = vim.schedule_wrap(function(_, exit_code)
        current_job = nil
        
        if exit_code == 0 then
          -- Streaming completed successfully
          callback(accumulated_response, nil)
        else
          -- Error occurred
          local error_msg = "Request failed"
          
          if accumulated_response ~= "" then
            -- We got some data, maybe partial
            callback(accumulated_response, "Connection interrupted, partial response received")
          else
            if buffer:match("SSL") or buffer:match("certificate") then
              error_msg = "SSL/Certificate error. Check your CA bundle path."
            elseif buffer:match("timeout") then
              error_msg = "Request timed out after " .. opts.timeout .. "s"
            elseif buffer:match("Connection refused") then
              error_msg = "Connection refused. Check API base URL."
            elseif buffer ~= "" then
              -- Try to parse error response
              local ok, data = pcall(vim.fn.json_decode, buffer)
              if ok and data.error then
                error_msg = data.error.message or vim.inspect(data.error)
              end
            end
            callback(nil, error_msg)
          end
        end
      end)
    }
    
    current_job = vim.fn.jobstart(cmd, job_opts)
    
  else
    -- Non-streaming mode (original behavior)
    local output = {}
    local job_opts = {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= "" then
              table.insert(output, line)
            end
          end
        end
      end,
      on_exit = vim.schedule_wrap(function(_, exit_code)
        current_job = nil
        
        if exit_code == 0 then
          local response_body = table.concat(output, "\n")
          
          -- Parse JSON response
          local ok, data = pcall(vim.fn.json_decode, response_body)
          if ok and data.choices and data.choices[1] then
            local content = data.choices[1].message.content
            callback(content, nil)
          else
            -- Try to get error message from response
            local error_msg = "Failed to parse response"
            if ok and data.error then
              error_msg = data.error.message or vim.inspect(data.error)
            end
            callback(nil, error_msg)
          end
        else
          local error_body = table.concat(output, "\n")
          local error_msg = string.format("HTTP request failed (exit code %d)", exit_code)
          
          -- Try to extract more specific error
          if error_body:match("SSL") or error_body:match("certificate") then
            error_msg = "SSL/Certificate error. Check your CA bundle path."
          elseif error_body:match("timeout") then
            error_msg = "Request timed out after " .. opts.timeout .. "s"
          elseif error_body:match("Connection refused") then
            error_msg = "Connection refused. Check API base URL."
          elseif error_body ~= "" then
            -- Try to parse error response
            local ok, data = pcall(vim.fn.json_decode, error_body)
            if ok and data.error then
              error_msg = data.error.message or vim.inspect(data.error)
            end
          end
          
          callback(nil, error_msg)
        end
      end)
    }
    
    current_job = vim.fn.jobstart(cmd, job_opts)
  end
  
  if current_job <= 0 then
    callback(nil, "Failed to start curl command")
  end
end

-- Test connection to API
function M.test_connection(callback)
  local opts = config.options
  local ca_bundle = vim.fn.expand(opts.ca_bundle_path)
  
  -- Simple request to check connection
  local cmd = {
    "curl",
    "-s",
    "-w", "\n%{http_code}",
    "-X", "GET",
    opts.api_base .. "/api/models",
    "--cacert", ca_bundle,
    "--max-time", "10",
    "-H", "Authorization: Bearer " .. opts.api_key
  }
  
  local output = {}
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(output, line)
          end
        end
      end
    end,
    on_exit = vim.schedule_wrap(function(_, exit_code)
      if exit_code == 0 and #output > 0 then
        -- Last line should be HTTP status code
        local http_code = tonumber(output[#output])
        if http_code and http_code >= 200 and http_code < 300 then
          callback(true, "Connection successful! API is reachable.")
        else
          callback(false, "API returned HTTP " .. (http_code or "unknown"))
        end
      else
        local error_msg = "Connection failed"
        local error_body = table.concat(output, "\n")
        
        if error_body:match("SSL") or error_body:match("certificate") then
          error_msg = "SSL/Certificate error. Check your CA bundle path: " .. ca_bundle
        elseif error_body:match("Could not resolve host") then
          error_msg = "Could not resolve host. Check API base URL."
        elseif error_body:match("Connection refused") then
          error_msg = "Connection refused. Server may be down or unreachable."
        end
        
        callback(false, error_msg)
      end
    end)
  })
end

-- Cancel current request
function M.cancel()
  if current_job and current_job > 0 then
    vim.fn.jobstop(current_job)
    current_job = nil
    return true
  end
  return false
end

return M
