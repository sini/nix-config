{
  sshKeyPath,
  name,
  email,
}:
''
  [user]
  	name = ${name}
  	email = ${email}
      signingkey = ${sshKeyPath}
  [pull]
  	rebase = true
  [init]
  	defaultBranch = main
  [filter "lfs"]
  	process = git-lfs filter-process
  	required = true
  	clean = git-lfs clean -- %f
  	smudge = git-lfs smudge -- %f
  [gpg]
      format = ssh
  [commit]
    gpgsign = true
''
