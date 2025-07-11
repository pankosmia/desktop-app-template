# CHANGELOG

## v0.3.0 (14 Jul 2025)
### General
- Fix scroll and page height issues
- Make margins/padding more consistent
- Upgrade fonts
- Various server refactoring and tweaking

### Download
- Use data grid instead of table (sort, filter)
- Use blended font
- Show one spinner per download
- Faster/more reliable switching between orgs

### Content
- Use data grid instead of table (sort, filter)
- Filter by language
- Create BCV project (tN, tQ, sQ)
- Create OBS project

### Workspace
- Match heading to tile size
- BCV resource editor (tN, tQ, sQ)
- OBS editor
- OBS viewer
- OBS resource viewers (tN, tW, tQ, sQ)
- Try cards in Masonry layout for resource picker
- Improved BCV viewers including accordion for questions and tW
- Images slideshow (eg FIA images and maps)
- Juxtalinear viewer
- Basic audio "viewer"

###	Desktop App Template
- Setup and Maintenance Scripts (linux, macos, and windows):
  - App setup - as per app config file
  - Clone - all client repos and resources as per app config file
  - Build clients - main branch of all clients as per app config file
  - Sync - keeps forks current with intended differences excluded
- Development Environment Scripts (linux, macos, and windows):
  - Build Server - builds the server and assembles client builds
  - Run - re-assembles client builds and starts the server
  - Clean - removes client builds and cleans the server
  - Bundle - packages the server and client builds
- Github Action Workflows (linux, macos, and windows):
  - Follows app config file
  - Clones all repos
  - Builds all clients
  - Builds server
  - Assembles artifacts (tgz, zip, exe, pkg)
  - Run manually from app repos as needed
