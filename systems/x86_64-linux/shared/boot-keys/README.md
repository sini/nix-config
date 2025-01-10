These keys are /not/ secret, they get stored in the global registry and initrd
and are exclusively used for remote disk unlocking.

TODO: Since we don't actually validate these, we can generate them during the
build process. I don't yet know enough nix to do that off the top of my head,
will look into it after I get some more services configured.
