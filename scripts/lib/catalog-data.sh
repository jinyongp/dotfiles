#!/usr/bin/env bash

# Columns:
# 1. id
# 2. label
# 3. visible_in_leaf_picker
# 4. brew_command_name
# 5. apt_command_name
# 6. brew_native_name
# 7. apt_native_name
# 8. brew_description
# 9. apt_description
catalog_data::package_rows() {
  cat <<'EOF'
jq	jq	1	jq	jq	jq	jq	Command-line JSON processor.	Command-line JSON processor.
gh	GitHub CLI	1	gh	gh	gh	gh	GitHub command-line client.	GitHub command-line client.
fd	fd	1	fd	fdfind	fd	fd-find	Fast file finder. Uses fd on brew.	Fast file finder. Uses fd-find on apt.
eza	eza	1	eza	eza	eza	eza	Modern replacement for ls.	Modern replacement for ls.
fzf	fzf	1	fzf	fzf	fzf	fzf	Command-line fuzzy finder.	Command-line fuzzy finder.
zoxide	zoxide	1	zoxide	zoxide	zoxide	zoxide	Smarter cd command with frecency.	Smarter cd command with frecency.
tldr	tldr	1	tldr	tldr	tlrc	tealdeer	Community-maintained command examples. Uses tlrc on brew.	Community-maintained command examples. Uses tealdeer on apt.
gnupg	GnuPG	1	gpg	gpg	gnupg	gnupg	GPG tooling for signing and encryption.	GPG tooling for signing and encryption.
diff-so-fancy	diff-so-fancy	1	diff-so-fancy	diff-so-fancy	diff-so-fancy	diff-so-fancy	Nicer Git diff presentation.	Nicer Git diff presentation.
fnm	fnm	1	fnm	fnm	fnm		Fast Node.js version manager via Homebrew.	Fast Node.js version manager via the official install script.
curl	curl	0	curl	curl	curl	curl	curl command.	curl command.
git	git	0	git	git	git	git	git command.	git command.
neovim	Neovim	0	nvim	nvim	neovim	neovim	Neovim editor.	Neovim editor.
ripgrep	rg	0	rg	rg	ripgrep	ripgrep	Fast recursive search tool.	Fast recursive search tool.
starship	starship	0	starship	starship	starship	starship	Starship prompt binary.	Starship prompt binary.
typescript	TypeScript	0	tsc	tsc			TypeScript compiler via npm.	TypeScript compiler via npm.
typescript-language-server	typescript-language-server	0	typescript-language-server	typescript-language-server			TypeScript language server via npm.	TypeScript language server via npm.
unzip	unzip	0	unzip	unzip	unzip	unzip	unzip command.	unzip command.
vim	vim	0	vim	vim	vim	vim	vim editor.	vim editor.
zsh	zsh	0	zsh	zsh	zsh	zsh	zsh shell.	zsh shell.
EOF
}

# Columns:
# 1. id
# 2. label
# 3. kind
# 4. source
# 5. description
catalog_data::font_rows() {
  cat <<'EOF'
font-fira-code-nerd-font	Fira Code Nerd Font	cask	font-fira-code-nerd-font	Homebrew cask font for terminal glyph coverage.
font-victor-mono-nerd-font	Victor Mono Nerd Font	cask	font-victor-mono-nerd-font	Homebrew cask font for terminal glyph coverage.
bundled-firacodeiscript	FiraCodeiScript (bundled)	bundled	FiraCodeiScript	Copy the bundled FiraCodeiScript font family into ~/Library/Fonts.
bundled-monocraft	Monocraft (bundled)	bundled	Monocraft	Copy the bundled Monocraft font family into ~/Library/Fonts.
EOF
}

# Columns:
# 1. id
# 2. label
# 3. visible_in_leaf_picker
# 4. source
# 5. description
catalog_data::desktop_app_rows() {
  cat <<'EOF'
arc	Arc	1	arc	Arc browser via Homebrew cask.
iterm2	iTerm2	1	iterm2	iTerm2 terminal emulator via Homebrew cask.
raycast	Raycast	1	raycast	Raycast launcher via Homebrew cask.
keka	Keka	1	keka	Keka archive utility via Homebrew cask.
kekaexternalhelper	KekaExternalHelper	0	kekaexternalhelper	Keka helper app via Homebrew cask.
karabiner-elements	Karabiner-Elements	1	karabiner-elements	Keyboard remapping utility via Homebrew cask.
visual-studio-code	Visual Studio Code	1	visual-studio-code	VS Code editor via Homebrew cask.
EOF
}

# Columns:
# 1. module id
# 2. item id
# 3. required item id
# 4. reason
catalog_data::required_item_rows() {
  cat <<'EOF'
packages	zoxide	fzf	zoxide requires fzf for interactive selection.
desktop_apps	keka	kekaexternalhelper	Keka requires KekaExternalHelper for Finder integration.
EOF
}
