# WordUp

A macOS menu bar app for uploading files and screenshots to self-hosted WordPress sites.

## Features

- **Menu Bar Integration**: Lives in the macOS menu bar for quick access (works properly in multi-monitor setups)
- **WordPress Authentication**: Uses Application Passwords for secure authentication
- **Drag & Drop Upload**: Simply drag files or screenshots onto the menu bar icon
- **Automatic Clipboard**: Uploaded media URLs are automatically copied to clipboard
- **Local Token Storage**: Securely stores authentication tokens locally
- **Modern Notifications**: Uses macOS UserNotifications framework for upload status alerts
- **Custom User-Agent**: Identifies requests with "WordUp/1.0 API Client by George Stephanis"

## Requirements

- macOS 13.0 or later
- Self-hosted WordPress site with REST API enabled (supports local development domains like .local)
- WordPress Application Password
- **For automatic screenshot uploads**: WordUp monitors your Desktop/Screenshots folder

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

**Method 1: Drag & Drop**
1. Take a screenshot or select any image file
2. Drag the file onto the WordUp icon in the menu bar
3. The file uploads automatically and the media URL is copied to your clipboard

**Method 2: Upload Files Button**
1. Click the WordUp menu bar icon
2. Click "Upload Files..." button
3. Select image files from the file picker
4. Files upload automatically and URLs are copied to clipboard

**Method 3: Automatic Screenshot Upload**
1. Take a screenshot using macOS screenshot tools (⌘⇧4, ⌘⇧5, etc.)
2. WordUp automatically detects and uploads the screenshot
3. Media URL is copied to your clipboard

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
