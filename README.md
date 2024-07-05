# p4-backup
A powershell script that implements the nightly backup procedere from the [Helix Core Server Administration Guide](https://www.perforce.com/manuals/p4sag/Content/P4SAG/backup-procedure.html).

# Assumptions
This script assumes that you

* Run Helix Core on a Windows (Server) machine.
* Run this script on that same machine.
* Do not have a custom license installed in P4ROOT.
* Do not need this script to cover you need to run p4 verify on a weekly basis.

