# WordUp

A macOS menu bar app for uploading files and screenshots to self-hosted WordPress sites.

## Features

- **Menu Bar Integration**: Lives in the macOS menu bar for quick access
- **WordPress Authentication**: Uses Application Passwords for secure authentication
- **Drag & Drop Upload**: Simply drag files or screenshots onto the menu bar icon
- **Automatic Clipboard**: Uploaded media URLs are automatically copied to clipboard
- **Local Token Storage**: Securely stores authentication tokens locally

## Requirements

- macOS 13.0 or later
- Self-hosted WordPress site with REST API enabled
- WordPress Application Password

## Setup

1. **Create Application Password in WordPress**:
   - Go to your WordPress admin dashboard
   - Navigate to Users → Profile
   - Scroll down to "Application Passwords"
   - Create a new application password for "WordUp"

2. **Install and Authenticate**:
   - Download and install WordUp.app
   - Click the menu bar icon and select "Authenticate"
   - Enter your WordPress site URL, username, and application password
   - Click "Authenticate"

## Usage

1. **Take a screenshot** or select any image/file
2. **Drag the file** onto the WordUp icon in the menu bar
3. The file will be uploaded to your WordPress media library
4. The media URL will be automatically copied to your clipboard
5. Paste the URL wherever you need it

## Security

- Authentication tokens are stored securely in macOS Keychain
- All communication with WordPress uses HTTPS
- Application passwords are specific to WordUp and can be revoked anytime

## Technical Details

- Built with SwiftUI for macOS
- Uses WordPress REST API v2 for uploads
- Supports common image formats (JPG, PNG, GIF, WebP)
- Multipart form data uploads for reliable file transfer

## Troubleshooting

**Upload fails**: Check your internet connection and WordPress site URL
**Authentication fails**: Verify your application password is correct and REST API is enabled
**Files not uploading**: Ensure the file format is supported and file size is reasonable

## Support

For issues or feature requests, please check the WordPress site configuration or contact support.
