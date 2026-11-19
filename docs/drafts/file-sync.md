# File sync

- user enables server via UI

- create the snapshot directory
  + use the standard application support directory
    * assume that the application support directory:
      - is not inside a cloud sync directory
      - is not indexed by Spotlight / Siri
      - is not backed up
      - verify the above if the snapshot directory is ever located elsewhere
  + verify the snapshot and music directories are on the same volume
  + verify the volume is APFS
  + make sure the snapshot directory is empty
  + create the snapshot with `clonefile(2)`
    * time this creation, if slow, create the individual artist directories
      with `clonefile(2)` instead
    
- build the manifest for the music library
  + relative file path
  + calculate hash using XXH3 and get size while hashing

```csv
path,size,hash
"<artist1>/<album1>/<track1.mp3>",12345,12345
"<artist1>/<album1>/<track2.mp3>",23456,23456
```

- server listens for HTTP on some port
  + choose a port like 8888 or pick an upper port at random?
  + can bonjour share the port during discovery by clients?
  + worry about TLS later
  + worry about authentication later

- advertise server
  + bonjour?

- client sends its device name as `User-Agent`

- if client has an old manifest creates the old file set in memory and deletes
  the old manifest file

- client requests the manifest: GET `/manifest`
  + server shows device name as an active connection
  + client saves it to `manifest.csv`
  + client creates the new file set in memory from the manfiest

- client builds the deletion set by removing all files in the new file set from
  the old file set, then deleting the remaining files, if any

- client builds the sync set by removing all unchanged files from the new file
  set

- use 100 MB as single request transfer limit
  + experiment with this size to find optimum

- client segments the sync set into sub-100 MB groups
  + each single file > 100 MB gets its own group
  + writes a CSV file for each group
  + sequential names
  + "pending" directory in application support

- client selects a CSV in "pending"
  + atomically moves it to the "syncing" directory
  + POSTs the CSV to `/files`
  + post body contains a CSV that lists the desired relative file paths
  + response is a tar file containing the requested files with relative paths
  + don't add checksum as tar file response is written dynamically
  + uses background URL transfer
  + tar file name matches CSV name in "sync" directory
  + do up to 6 of these simultaneously

```csv
path
"<artist1>/<album1>/<track1.mp3>"
"<artist1>/<album1>/<track2.mp3>"
```

- as each `/files` request completes:
  + client un-tars each tar file directly into/over the music directory
  + deletes the tar file
  + deletes the corresponding CSV in the "syncing" directory
  + atomically select the next CSV file in "pending" and repeats

- when there are no more CSV files in "pending"
  + client POSTs to `/status`

```json
{"status":"complete"}
```

- the server and client end connections

- user disables server via UI or app terminates
  + stop advertising via bonjour
  + remove snapshot
