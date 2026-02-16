return {
  "herschel21/VayAI.nvim",
  config = function()
    require('vayai').setup()
  end
}
-- OR 

return {
    dir = '~/workspace/work/vayavya/neovim_plugins/VayAI.nvim/',  -- Local path
    config = function()
        require('vayai').setup()
    end
}

