defmodule Mix.Tasks.Watch do
  use Mix.Task

  @shortdoc """
  Watch one or more directories for changes, and then run the given
  mix task(s)
  """
  def run(args) when is_list(args) do
    args
    |> parse
    |> Mix.Tasks.Watch.Notifier.start_link
    |> wait_forever
  end
 

  # The default is to monitor lib/, test/ and mix.exs, running tests on change
  defp parse([]) do
    { ~W{mix.exs lib/**/*exs?  test/**/*exs?}, ~W{test} }
  end
  defp parse(args) do
    { path_list, rest } = extract_path_list(args)
    task_list           = extract_task_list(rest, args)
    {path_list, task_list}
  end

  
  defp extract_path_list(["on:" | args]), do: Enum.split_while(args, &(&1 != "do:"))
  defp extract_path_list(other),          do: usage(other)

  defp extract_task_list(["do:" | args], _), do: args
  defp extract_task_list(_other, args),      do: usage(args)
  
  defp usage(args) do
    Mix.shell.info([:normal, :red, "Invalid options ",
                    :bright, "'mix watch ",
                    :bright, :yellow, Enum.join(args, " "),
                    :normal, "'"])
    Mix.shell.info("(expected 'mix watch on: path1 path2… do: task1 task2…')")
    exit {:shutdown, 1}
  end

  defp wait_forever(arg) do
    receive do
      :ninety_nine_bottles_of_elixir_on_the_wall ->
        wait_forever(arg)
    end
  end
end
