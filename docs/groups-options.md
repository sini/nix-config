- `groups`: Shared group definitions used by Kanidm, Unix accounts, and host
  login gates

- `groups.<name>.description`: [string] Human-readable purpose of this group

- `groups.<name>.members`: [list of string] Other groups whose members are
  transitively included in this group

- `groups.<name>.scope`: [one of "kanidm", "unix", "system"] Scope determines
  which provisioners consume this group
