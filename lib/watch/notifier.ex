defmodule Mix.Tasks.Watch.Notifier do

  use     GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init({paths, tasks}) do 
    parsed_paths = parse_paths(paths)
    notifier_port = parsed_paths |> Enum.map(&(&1.path))   |> create_notifier
    matcher = parsed_paths |> Enum.map(&(&1.file_pattern)) |> create_matcher(System.cwd)
    {:ok, %{port: notifier_port, matcher: matcher, tasks: tasks}}
  end


  def handle_info({port, {:data, {flag, line}}},
                  state = %{port: port, tasks: tasks, matcher: matcher})
  when flag in [:eol, :noeol]  
  do
    line = to_string(line)
    if !spurious(line) && Regex.match?(matcher, line) do
      run_tasks(tasks)
    end
    { :noreply, state }
  end

  def handle_info({port, {:exit_status, status}}, state = %{port: port}) do
    {:stop, {:watcher_exit, status}, state}
  end

  # create a notifier process. Currently assumes fswatch is installed          
  defp create_notifier(paths) do
    cwd = System.cwd
    fs_watch = "fswatch" |> to_char_list |> :os.find_executable
    :erlang.open_port({:spawn_executable, fs_watch},
                      [:stream,
                       :exit_status,
                       {:line, 16384},
                       {:args, paths},
                       {:cd, to_char_list(cwd)}])
  end
 
  defp run_tasks(tasks) do
    Mix.shell.info "watch is running: #{Enum.join(tasks, ", ")}"
    for task <- tasks do
      #      Mix.Task.reenable(task)
      Mix.Task.clear
      change_env(task) 
      Mix.Task.run(task, (if task == "compile", do: ["--force"], else: []))
    end
  end

  ## Grrr... these are private in Mix.CLI
  defp change_env(task) do
    if is_nil(System.get_env("MIX_ENV")) &&
       (env = preferred_cli_env(task)) do
      Mix.env(env)
    end
  end

  defp preferred_cli_env(task) do
    task = String.to_atom(task)
    Mix.Project.config[:preferred_cli_env][task] || default_cli_env(task)
  end

  defp default_cli_env(:test), do: :test
  defp default_cli_env(_),     do: nil

  # Given a list like `["mix.exs", "lib/**/*exs?", "test/**/*exs?"]`
  # return a list of the directory part and the regular expression
  # the actual filename must match

  @path_re ~r{^((?:[^*/]+/)*)(\*\*/)?(.*)$}
  defp parse_paths(paths) do
    for path <- paths do
      Regex.run(@path_re, path) |> parse_path_components
    end
  end

  defp parse_path_components(nil) do
    Mix.raise "Invalid path to watch"
  end

  defp parse_path_components([_, dir, _wildcard, file_pattern]) do
    %{ path: dir, file_pattern: pattern_to_regex(dir, file_pattern) }
  end

  @literal_star  Regex.compile!(Regex.escape("\\*"))   
  @question_mark Regex.compile!(Regex.escape("\\?"))  
  defp pattern_to_regex(dir, file_pattern) do
    dir          = Regex.escape(dir)
    file_pattern = Regex.escape(file_pattern)
    file_pattern = Regex.replace(@literal_star, file_pattern, ".*")
    file_pattern = Regex.replace(@question_mark, file_pattern, "?")
    dir <> file_pattern
  end 

  defp create_matcher(patterns, cwd) do
    full_paths = for pattern <- patterns, do: Path.join(cwd, pattern)
    Regex.compile!("^((" <> Enum.join(full_paths, ")|(") <> "))$")
  end

  @files_to_ignore ~r{/.#}
  defp spurious(path), do: Regex.match?(@files_to_ignore, path)                      

end
