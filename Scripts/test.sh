#!/bin/bash
TMP="$(mktemp /tmp/menu.XXXXXX)"
trap "[ -f "$TMP" ] && rm -f $TMP" HUP INT QUIT TERM EXIT
$DIA --backtitle "$msg_nchc_free_software_labs" --title  \
"$msg_nchc_clonezilla" --menu "$msg_choose_mode:" \
0 0 0 \
"Backup"  "Backup $src_part to $tgt_part" \
"Restore" "Restore the image in $tgt_part to $src_part" \
2> $TMP
mode="$(cat $TMP)"
[ -f "$TMP" ] && rm -f $TMP

#
case "$mode" in
  Backup)
    action_backup;;
  Restore)
    action_restore;;
  *)
    [ "$BOOTUP" = "color" ] && $SETCOLOR_FAILURE
    echo "Program terminated!"
    [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
    exit 1
esac

# Select partition image
IFS= mapfile -t files < <(ls -t -d /media/tyler/Cold\ HDD/Clonezilla/*)
select d in "${files[@]}"
do
    test -n "$d" && break
    echo ">>> Wrong Folder Selection!!! Try Again"
done

