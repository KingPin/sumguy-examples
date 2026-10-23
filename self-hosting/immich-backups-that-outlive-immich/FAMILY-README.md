# Family Photos: How To Get To Them

If you are reading this, the photo server may be switched off or no one is
looking after it. The photos are still safe. This page tells you how to reach them.

## Where the photos are

- Server folder: `/srv/immich/library` (replace with the real path)
- Offsite copy: a restic repository at `s3:s3.example.com/family-photos`
- Repository password: stored in the password manager, entry "Family photos backup"
- Person who set this up: NAME, PHONE

## The easy way: open the folders

1. Open the `library` folder in any file browser.
2. Open a user folder, then a year, then a day. Each photo is a normal JPG, HEIC, or video file.
3. Open `export/albums` to browse by album. Open `export/people` to browse by person.

You do not need Immich for any of this.

## If the server is gone: restore from the offsite copy

1. Install restic from https://restic.net.
2. Open a terminal and run:

   ```
   export RESTIC_REPOSITORY="s3:s3.example.com/family-photos"
   export RESTIC_PASSWORD="the-password-from-the-password-manager"
   restic restore latest --target ./family-photos
   ```

3. Open the `family-photos` folder, then go down through the original server path
   (for example `srv/immich`). Inside it you find `library` and `export`, laid out as above.

## If you want a photo app again

Ask a technical friend to install Immich and use the newest file in `backups/`
(ends in `.sql.gz`) with the Immich restore screen. The Immich docs describe it
at https://docs.immich.app/administration/backup-and-restore.

## Search tools that need no server

- digiKam (free, Windows, macOS, Linux) opens the `library` folder and reads
  dates, places, and tags from the files and from the `.xmp` files next to them.
