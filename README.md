# Toraih's EpicGames Gamefolder Mover

This script automates the process of moving Epic Games installation folders between library locations for the Epic Games Launcher.

## Usage

1. Run the script with administrator privileges.
2. Follow the on-screen prompts to select the installation you want to move and the target library location.

## Features

- Checks if running with administrator privileges.
- Verifies if the Epic Games Launcher process is running.
- Automatically detects paths for `LauncherInstalled.dat` and manifests folder.
- Lists existing Epic Games library locations.
- Moves an installation to a selected library location.
- Updates the necessary paths in `LauncherInstalled.dat` and manifest files.

## Customization

You can customize the script by modifying the following variables in the script:

- `$launcherInstalled`: Path to `LauncherInstalled.dat` file.
- `$manifestsFolder`: Path to the manifests folder.
- `$filter`: Filter installations based on a specific condition.

## Important Notes

- Make sure to run the script with administrative privileges.
- Confirm that the Epic Games Launcher is not running before proceeding.
- Ensure that you have enough free space in the target library location.

## License

This script is released under the [MIT License](LICENSE).
