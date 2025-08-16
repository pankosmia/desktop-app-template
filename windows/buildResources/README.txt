#%%APP_NAME%% %%APP_VERSION%% Windows

For first use of any app built on Pankosmia, simply launch %%APP_NAME%%.

If unsure, check to see if `~\panksomia_working\` and\or `~\panksomia_repos\` already exist.
  If neither exists, then follow the "First use" instructions above.
  If `~\panksomia_working\` exists, but not `~\panksomia_repos\`, then follow the "Upgrade from versions prior to 0.4.0-rc1" instructions below.
  If both `~\panksomia_working\` and `~\panksomia_repos\` already exist, then follow the "Upgrade from 0.4.0-rc1 or greater" instructions below.

Upgrade from versions prior to 0.4.0-rc1:
  1. Make a copy of `~\panksomia_working\repos` where "~" is the OS user home directory.
      ***************************************************************************************
      * Prior to 0.4.0, local projects were stored inside `~\pankosmia_working`.            *
      * Starting with 0.4.0 they are stored separately in `~\pankosmia_repos`.              *
      * Be very careful to backup before deleting pankosmia_working on older installations. *  
      ***************************************************************************************
  2. Delete `~\panksomia_working\`
  3. Launch %%APP_NAME%%
  4. Restore the backup copy from step 1 to `~\panksomia_repos\` such that the prior immediate subdirectories of `~\panksomia_working\repos` are now immediate subdirectores of `~\panksomia_repos\`.
     The resulting directory structure should be along the lines of the following
     ~
     └───panksomia_repos
         ├───_git.door43.org
         │   └───[...more subdirectories]
         └───_local_
             └───_local_
                 └───[...more subdirectories]

Upgrade from 0.4.0-rc1 or greater:
  1. Delete `~\panksomia_working\`
  2. Launch %%APP_NAME%%

This app leverages Graphite-enabled Electronite for font feature support.