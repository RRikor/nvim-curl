fun! Reload()
    lua for k in pairs(package.loaded) do if k:match("^cu%-nvim") then package.loaded[k] = nil end end
endfun

fun! CU()
    call Reload()
    lua require("cu-nvim").handle()
endfun

fun! Reuse()
    call Reload()
    lua require("cu-nvim").reuse()
endfun

command! CurlInsert new | e ~/Octo/api_urls | set syntax=bash
map <leader>cu :call CU()<CR>
map <leader>ci :CurlInsert<CR>
map <leader>cr :call Reuse()<CR>
