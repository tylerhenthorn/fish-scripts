function transcribe-audio -d "Transcribe audio file using local Whisper with JSON output"
    # Init vars
    set -l input_file ""
    set -l output_dir ""
    set -l model "base"
    set -l language ""
    set -l task "transcribe"
    set -l word_timestamps true
    set -l verbose true
    set -l next_is_lang false
    set -l next_is_model false
    set -l next_is_output false

    # Parse args
    for arg in $argv
        if test "$next_is_lang" = true
            set language $arg
            set next_is_lang false
        else if test "$next_is_model" = true
            set model $arg
            set next_is_model false
        else if test "$next_is_output" = true
            set output_dir $arg
            set next_is_output false
        else
            switch $arg
                case --lang --language
                    set next_is_lang true
                case --model
                    set next_is_model true
                case -o --output
                    set next_is_output true
                case --no-word-timestamps
                    set word_timestamps false
                case --translate
                    set task "translate"
                case --quiet
                    set verbose false
                case -h --help
                    echo "Usage: transcribe-audio [options] <audio_file>"
                    echo "Options:"
                    echo "  --lang <code>        Specify language (e.g., en, es, fr)"
                    echo "  --model <size>       Model size: tiny, base, small, medium, large (default: base)"
                    echo "  -o, --output <dir>   Output directory (default: same as input)"
                    echo "  --translate          Translate to English instead of transcribe"
                    echo "  --no-word-timestamps Disable word-level timestamps"
                    echo "  --quiet              Suppress progress output"
                    echo "  -h, --help           Show this help"
                    return 0
                case '*'
                    if test -z "$input_file"
                        set input_file $arg
                    end
            end
        end
    end

    # Validate input
    if test -z "$input_file"
        echo "Error: no input file specified"
        echo "Usage: transcribe-audio [options] <audio_file>"
        return 1
    end

    if not test -f "$input_file"
        echo "Error: file '$input_file' not found"
        return 1
    end

    # Check whisper available
    if not command -v whisper >/dev/null
        echo "Error: whisper not found"
        echo "Install: pip install openai-whisper"
        return 1
    end

    # Set output dir to input dir if not specified
    if test -z "$output_dir"
        set output_dir (dirname "$input_file")
    end

    if not test -d "$output_dir"
        echo "Error: output directory '$output_dir' not found"
        return 1
    end

    # Build whisper cmd
    set -l whisper_cmd whisper "$input_file"
    set whisper_cmd $whisper_cmd --output_dir "$output_dir"
    set whisper_cmd $whisper_cmd --output_format json
    set whisper_cmd $whisper_cmd --model $model
    set whisper_cmd $whisper_cmd --task $task

    if test -n "$language"
        set whisper_cmd $whisper_cmd --language $language
    end

    if test "$word_timestamps" = true
        set whisper_cmd $whisper_cmd --word_timestamps True
    end

    if test "$verbose" = false
        set whisper_cmd $whisper_cmd --verbose False
    end

    # Show config
    echo "Transcription config:"
    echo "  Input: $input_file"
    echo "  Output dir: $output_dir"
    echo "  Model: $model"
    if test -n "$language"
        echo "  Language: $language"
    else
        echo "  Language: auto-detect"
    end
    echo "  Task: $task"
    echo ""

    # Run transcription
    eval $whisper_cmd
    set whisper_status $status

    if test $whisper_status -ne 0
        echo ""
        echo "Error: transcription failed with exit code $whisper_status"
        return 1
    end

    # Verify output
    set -l basename (path change-extension '' (path basename "$input_file"))
    set -l json_output "$output_dir/$basename.json"

    if not test -f "$json_output"
        echo ""
        echo "Error: expected JSON output not found: $json_output"
        return 1
    end

    echo ""
    echo "Transcription complete: $json_output"

    # Show summary if jq available
    if command -v jq >/dev/null
        echo ""
        echo "Summary:"
        set -l detected_lang (jq -r '.language // "unknown"' "$json_output")
        set -l segment_count (jq '.segments | length' "$json_output")
        echo "  Detected language: $detected_lang"
        echo "  Segments: $segment_count"
    end
end
