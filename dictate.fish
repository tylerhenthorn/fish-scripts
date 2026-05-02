function dictate -d "Record mic audio, transcribe with Whisper, copy to clipboard"
    set -l tmpwav (mktemp -t dictation-XXXX.wav)

    function __dictate_cleanup --on-signal INT --inherit-variable rec_pid --inherit-variable tmpwav
        kill $rec_pid 2>/dev/null
        rm -f $tmpwav
        functions -e __dictate_cleanup
    end

    echo "Recording... press Enter to stop."
    rec -r 16000 -c 1 $tmpwav &
    set -l rec_pid $last_pid
    read -P ""
    kill $rec_pid 2>/dev/null
    wait $rec_pid 2>/dev/null

    echo "Transcribing..."
    whisper $tmpwav --model tiny --language en --output_format txt --output_dir /tmp 2>/dev/null
    string join ' ' <(string replace .wav .txt $tmpwav) | string trim | xsel --clipboard --input
    rm -f (string replace .wav .txt $tmpwav)
    rm -f $tmpwav
    functions -e __dictate_cleanup
    echo "Copied to clipboard."
end
