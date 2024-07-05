# p4-backup
A powershell script that implements the nightly backup procedere from the [Helix Core Server Administration Guide](https://www.perforce.com/manuals/p4sag/Content/P4SAG/backup-procedure.html).
It does the following:

1. Deletes all old checkpoints (since only the latest one is needed)
2. Creates a new checkpoint.
3. Checks the MD5 checksum of the created checkpoint against the MD5 file produced by the creation process.
4. Creates a new backup directory with the current date.
5. Copies checkpoint & journal files + all folders in P4ROOT, except for server.locks.
6. Deletes backup folders that are older than 7 days.

# Assumptions
This script assumes that you

* Run Helix Core on a Windows (Server) machine.
* Run this script on that same machine.
* Do not have a custom license installed in P4ROOT.
* Do not need this script to cover you need to run p4 verify on a weekly basis.

