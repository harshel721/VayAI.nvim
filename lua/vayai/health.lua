local M = {}

function M.check()
  vim.health.start("VayAI.nvim")

  -- Check curl
  if vim.fn.executable("curl") == 1 then
    vim.health.ok("curl is installed")
    
    -- Check curl version (optional but good for debugging)
    local curl_version = vim.fn.system("curl --version | head -n 1"):gsub("\n", "")
    vim.health.info("curl version: " .. curl_version)
  else
    vim.health.error("curl is not installed. This plugin requires curl.")
  end

  -- Try to load config
  local ok, config = pcall(require, 'vayai.config')
  if not ok then
    vim.health.error("Could not load vayai.config")
    return
  end
  
  local opts = config.options

  -- Check API Base URL
  if opts.api_base and opts.api_base ~= "" then
    vim.health.ok("API base URL: " .. opts.api_base)
  else
    vim.health.error("API base URL is not configured.")
  end

  -- Check API Key
  if opts.api_key and opts.api_key ~= "" then
    vim.health.ok("API key is configured")
  else
    vim.health.warn("API key is not configured. Set LLM_API_KEY environment variable or configure in setup().")
  end

  -- Check CA Bundle
  if opts.ca_bundle_path and opts.ca_bundle_path ~= "" then
    local path = vim.fn.expand(opts.ca_bundle_path)
    if vim.uv.fs_stat(path) then
      vim.health.ok("CA bundle found at: " .. path)
    else
      vim.health.error("CA bundle NOT found at: " .. path)
    end
  else
    vim.health.warn("CA bundle path is not configured. SSL verification might fail if the server uses a self-signed certificate.")
  end

  -- Check Models
  if opts.models and #opts.models > 0 then
    vim.health.ok("Configured models: " .. table.concat(opts.models, ", "))
  else
    vim.health.warn("No models configured.")
  end
  
  if opts.default_model then
    vim.health.info("Default model: " .. opts.default_model)
  end
end

return M
