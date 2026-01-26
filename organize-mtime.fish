function organize-mtime -d "Move files into date folders by mtime (default: YYYYMM). Flags: --daily (YYYYMMDD), --yearly (YYYY), --monthly (YYYYMM), -r for recursive, -n for dry-run."
    # Parse arguments
    set -l dry_run false
    set -l recursive false
    set -l date_format '%Y%m'  # Default: monthly YYYYMM

    for arg in $argv
        switch $arg
            case -n --dry-run
                set dry_run true
            case -r --recursive
                set recursive true
            case --daily
                set date_format '%Y%m%d'
            case --yearly
                set date_format '%Y'
            case --monthly
                set date_format '%Y%m'
        end
    end

    function read_confirm -V dry_run
        set -l mode_text "Organize"
        if test "$dry_run" = true
            set mode_text "Preview organization of"
        end
        while true
            read -l -P "$mode_text "(pwd)"? [y/N] " confirm
            switch $confirm
            case Y y
                return 0
            case '' N n
                return 1
            end
        end
    end

    function move_to_date_folder -V files_moved -V files_skipped -V folders_created -V folders_seen
        set -l file $argv[1]
        set -l dry_run_flag $argv[2]
        set -l format $argv[3]
        set -l mtime (stat -c %Y $file 2>/dev/null; or stat -f %m $file 2>/dev/null)

        if test -z "$mtime"
            echo "Skipped (stat failed): $file"
            set files_skipped (math $files_skipped + 1)
            return 1
        end

        set -l folder (date --date=@$mtime +"$format" 2>/dev/null; or date -r $mtime +"$format")

        if test "$dry_run_flag" = true
            echo "Would move: $file → $folder/"
            set folders_seen $folders_seen $folder
        else
            mkdir -p $folder
            if mv -n $file $folder/
                echo "$file → $folder/"
                set folders_created $folders_created $folder
            else
                echo "Skipped (mv failed): $file"
                set files_skipped (math $files_skipped + 1)
                return 1
            end
        end
        set files_moved (math $files_moved + 1)
    end

    if read_confirm
        # Initialize counters
        set -g files_moved 0
        set -g files_skipped 0
        set -g folders_created
        set -g folders_seen

        # Choose find depth
        set -l find_cmd "find . -maxdepth 1 -type f"
        if test "$recursive" = true
            set find_cmd "find . -type f"
        end

        for f in (eval $find_cmd)
            move_to_date_folder $f $dry_run $date_format
        end

        # Summary
        if test "$dry_run" = true
            set -l unique_folders (printf '%s\n' $folders_seen | sort -u | count)
            echo ""
            echo "Dry-run complete: would organize $files_moved files into $unique_folders folders"
        else
            set -l unique_folders (printf '%s\n' $folders_created | sort -u | count)
            echo ""
            echo "Organized $files_moved files into $unique_folders folders"
            find . -type d -empty -delete
        end

        if test $files_skipped -gt 0
            echo "Skipped $files_skipped files"
        end

        # Cleanup global vars
        set -e files_moved
        set -e files_skipped
        set -e folders_created
        set -e folders_seen
    end
end