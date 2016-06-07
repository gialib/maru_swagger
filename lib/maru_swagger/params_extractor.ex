defmodule MaruSwagger.ParamsExtractor do
  alias Maru.Struct.Parameter.Information

  defmodule NonGetBodyParamsGenerator do
    def generate(param_list, path) do
      {path_param_list, body_param_list} = param_list |> MaruSwagger.ParamsExtractor.filter_information |> Enum.partition(&(&1.attr_name in path))
      [ format_body_params(body_param_list) |
        format_path_params(path_param_list)
      ]
    end

    defp default_body do
      %{ name: "body",
         in: "body",
         description: "",
         required: false,
       }
    end

    defp format_path_params(param_list) do
      Enum.map(param_list, fn param ->
        %{ name:        param.param_key,
           description: param.desc || "",
           type:        param.type,
           required:    param.required,
           in:          "path",
         }
      end)
    end

    defp format_body_params(param_list) do
      param_list
      |> Enum.map(fn param ->
        { param.param_key,
          %{ description: param.desc || "",
             type:        param.type,
             required:    param.required,
           }
        }
      end)
      |> case do
        []     -> default_body
        params ->
          params = Enum.into(params, %{})
          default_body
          |> put_in([:schema], %{})
          |> put_in([:schema, :properties], params)
      end
    end
  end

  defmodule NonGetFormDataParamsGenerator do
    def generate(param_list, path) do
      param_list
      |> MaruSwagger.ParamsExtractor.filter_information
      |> Enum.map(fn param ->
        %{ name:        param.param_key,
           description: param.desc || "",
           type:        param.type,
           required:    param.required,
           in:          param.attr_name in path && "path" || "formData",
         }
      end)
    end
  end

  alias Maru.Struct.Route
  def extract_params(%Route{method: {:_, [], nil}}=ep) do
    %{ep | method: "MATCH"} |> extract_params
  end

  def extract_params(%Route{method: "GET", path: path, parameters: parameters}) do
    for param <- parameters do
      %{ name:        param.param_key,
         description: param.desc || "",
         required:    param.required,
         type:        param.type,
         in:          param.attr_name in path && "path" || "query",
      }
    end
  end
  def extract_params(%Route{method: "GET"}), do: []
  def extract_params(%Route{parameters: []}), do: []

  def extract_params(%Route{parameters: param_list, path: path}) do
    param_list = filter_information(param_list)
    # {file_param_list, param_list} = split_file_list_and_rest(parameters)
    # file_param_list_swagger       = convert_file_param_list_to_swagger(file_param_list)
    # param_list_swagger            = convert_param_list_to_swagger(param_list)
    (case judge_adapter(param_list) do
      :body      -> NonGetBodyParamsGenerator
      :form_data -> NonGetFormDataParamsGenerator
    end).generate(param_list, path)
  end

  defp judge_adapter([]),                    do: :form_data
  defp judge_adapter([%{children: []} | t]), do: judge_adapter(t)
  defp judge_adapter(_),                     do: :body

  def filter_information(param_list) do
    Enum.filter(param_list, fn
      %Information{} -> true
      _              -> false
    end)
  end

end
