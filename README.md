# nvim-runscript
Neovim users, you may not need Postman

![nvim-runscript-demo](https://user-images.githubusercontent.com/61080/180638392-bc5fcb73-fe54-4af5-a256-926dfaf5a766.gif)


## Requirement

Developed and tested it on neovim v0.7


## Install


Install with packer:
```lua
use {
  "klesh/nvim-runscript",
  config = function() require("nvim-runscript").setup{} end
}
```

## How to use

1. Open a executable script file, i.e. `example/github/get-repo-detail.sh`.
2. Run commands `:RunScript`.
    1. A RESULT buffer should be appear on the bottom.
    2. The output of the process should be piped to the RESULT buffer.
    3. A markdown file wil be saved into `example/github/get-repo-detail.sh.result/`.
3. You may re-run the script from RESULT buffer.

