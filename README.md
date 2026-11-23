# WordUp

> [!TIP]
> **Look before you build.** Similar open-source projects:
>
> - [uPic](https://github.com/gee1k/uPic): macOS image and file uploader for many hosts, Apache-2.0
> - [PicGo](https://github.com/Molunerfinn/PicGo): desktop image uploader, MIT
> - [ShareX](https://github.com/ShareX/ShareX): Windows capture and upload tool with custom uploaders, GPL-3.0
>
> Before building your own tool, search [AlternativeTo](https://alternativeto.net) (filter to open source), [GitHub](https://github.com/search?type=repositories) and [wvw.dev](https://wvw.dev) for something to fork, this repo included.

A macOS menu bar app for uploading files and screenshots to self-hosted WordPress sites.

## License

All code in this repository, to [the extent that it is copyrightable](https://www.copyright.gov/ai/) (being partially created via LLM generation) is made available through the same GPL license through which WordPress is distributed.

The WordUp project is non-commercial in nature, being available for free, and is released with the hope of being useful to people and helping to promote the spread and improvement of the WordPress software.

It is a project by [George Stephanis](https://georgestephanis.wordpress.com/resume/), the same guy who [advocated for and got Application Passwords included in WordPress Core](https://make.wordpress.org/core/2020/11/05/application-passwords-integration-guide/), which this project leverages for authentication. The WordUp project is _not_ created by, endorsed, or supported by the WordPress Foundation, Automattic, or the WordPress Open Source Project.

As such, it falls under the [Trademark Usage Policy from the WordPress Foundation](https://wordpressfoundation.org/trademark-policy/) for its usage of the WordPress name and logo.

## Features

- **Menu Bar Integration**: Lives in the macOS menu bar for quick access (works properly in multi-monitor setups)
- **WordPress Authentication**: Uses Application Passwords for secure authentication
- **Drag & Drop Upload**: Simply drag files or screenshots onto the menu bar icon
- **Automatic Clipboard**: Uploaded media URLs are automatically copied to clipboard
- **Keychain Token Storage**: Stores your application password in the macOS Keychain
- **Modern Notifications**: Uses macOS UserNotifications framework with async/await (no deprecated APIs)
- **API Logging**: Complete request/response logging with searchable log viewer
- **Custom Menu Icon**: Distinctive "W" in blue circle outline with bold green upward arrow indicating WordPress connectivity and uploads
- **Smart Popover Dismissal**: Menus automatically close when clicking elsewhere on screen
- **Custom User-Agent**: Identifies requests with "WordUp/1.0 API Client by George Stephanis"

## Requirements

- macOS 15.6 or later (Apple Silicon or Intel)
- Self-hosted WordPress site with REST API enabled (supports local development domains like .local)
- WordPress Application Password
- **For screenshot uploads**: Drag screenshot files from Desktop/Screenshots folder

## Download

Get `WordUp-<version>-macOS.zip` from the [latest release](https://github.com/georgestephanis/WordUp/releases/latest), unzip it, and move `WordUp.app` to Applications.

The app is not notarized by Apple, so the first launch is blocked. To allow it once:

1. Open WordUp. macOS says Apple could not verify that WordUp is free of malware; click **Done**.
2. Open **System Settings › Privacy & Security**, scroll down, and click **Open Anyway** next to the WordUp message.
3. Open WordUp again, click **Open Anyway** in the dialog, and enter your Mac password. After that it opens normally.

Or, from Terminal: `xattr -dr com.apple.quarantine /Applications/WordUp.app`

To build it yourself instead, open `WordUp.xcodeproj` in Xcode and run the `WordUp` scheme.

## Setup

1. **Ensure Application Passwords are enabled**:

   - WordPress 5.6+ has Application Passwords built-in
   - For older versions, install the Application Passwords plugin

2. **Install and Authenticate**:
   - Download and install WordUp.app
   - Click the menu bar icon and select "Authenticate"
   - Enter your WordPress site URL (e.g., `yoursite.com` or `https://yoursite.com`)
   - HTTP URLs are automatically upgraded to HTTPS for security
   - Click "Connect to WordPress" or press Enter
   - The menu will automatically close and your browser will open to WordPress authorization page
   - Log in to WordPress (if not already logged in)
   - Approve the "WordUp" application
   - The menu will automatically update to show your authenticated site and username

## Usage

### File Upload Methods

**Method 1: Direct Drag & Drop to Icon**

1. Take a screenshot or select any image file
2. Drag the file directly onto the WordUp menu bar icon
3. Drop the file - no menus or windows needed
4. The file uploads automatically and the media URL is copied to your clipboard

_Alternative: You can also click the icon to open the menu and drag files into the interface_

**Method 2: Upload Files Button**

1. Click the WordUp menu bar icon
2. Click "Upload Files..." button (menu closes automatically)
3. Select image files from the file picker
4. Files upload automatically and URLs are copied to clipboard

**Method 3: Automatic Screenshot Upload**

1. Take a screenshot using macOS screenshot tools (⌘⇧4, ⌘⇧5, etc.)
2. WordUp automatically detects and uploads the screenshot to WordPress using Spotlight metadata
3. Media URL is copied to your clipboard

_Note: Requires authentication and Spotlight indexing to be enabled for automatic uploads_

### Settings

Access connection details and account management:

1. Click the WordUp menu bar icon
2. Click "Settings"
3. View connection details (site URL, username, status)
4. Verify connection or sign out

### Features

- **Supported Formats**: PNG, JPEG, GIF, WebP, SVG
- **Multiple Files**: Upload multiple files at once via drag & drop or file picker
- **Clipboard Integration**: Media URLs automatically copied to clipboard
- **Notifications**: Success/failure notifications for all uploads
- **Authentication Required**: Must be authenticated to upload files

## Security

- Authentication tokens are stored securely in macOS Keychain
- All communication with WordPress uses HTTPS
- Application passwords are specific to WordUp and can be revoked anytime

## Technical Details

- Built with SwiftUI for macOS
- Uses WordPress Application Passwords authentication flow
- Implements custom URL scheme (`wordup://`) for secure callback handling
- Uses WordPress REST API v2 for uploads
- Supports common image formats (JPG, PNG, GIF, WebP)
- Multipart form data uploads for reliable file transfer

## Troubleshooting

**Upload fails**: Check your internet connection and WordPress site URL
**Authentication fails**: Verify your application password is correct and REST API is enabled
**Files not uploading**: Ensure the file format is supported and file size is reasonable

## Support

For issues or feature requests, please check the WordPress site configuration or contact support.
