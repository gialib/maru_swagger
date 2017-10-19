defmodule MaruSwagger.ResponseFormatterTest do
  use ExUnit.Case, async: true
  doctest MaruSwagger.ResponseFormatter
  alias MaruSwagger.ConfigStruct
  import Plug.Test

  def get_response(module, conn) do
    res = module.call(conn, [])
    {:ok, json} = res.resp_body  |> Poison.decode(keys: :atoms)
    json
  end

  describe "basic test" do
    defmodule BasicTest.Homepage do
      use Maru.Router
      version "v1"

      desc "hello world action"
      params do
        requires :id, type: Integer
      end
      get "/" do
        _ = params
        conn |> json(%{ hello: :world })
      end

      desc "creates res1"
      params do
        requires :name, type: String
        requires :email, type: String
      end
      post "/res1" do
        conn |> json(params)
      end
    end

    defmodule BasicTest.API do
      use Maru.Router
      @make_plug true
      use MaruSwagger

      swagger at:     "/swagger/v1.json", # (required) the mount point for the URL
              pretty: true,               # (optional) should JSON be pretty-printed?
              swagger_inject: [           # (optional) this will be directly injected into the root Swagger JSON
                host:     "myapi.com",
                basePath: "/api",
                schemes:  [ "http" ],
                consumes: [ "application/json" ],
                produces: [
                  "application/json",
                  "application/vnd.api+json"
                ]
              ]

      mount MaruSwagger.ResponseFormatterTest.BasicTest.Homepage
    end

    test "includes basic information for swagger (title, API version, Swagger version)" do
      swagger_docs =
        %ConfigStruct{
          module: MaruSwagger.ResponseFormatterTest.BasicTest.Homepage,
        } |> MaruSwagger.Plug.generate


      assert swagger_docs |> get_in([:info, :title]) == "Swagger API for MaruSwagger.ResponseFormatterTest.BasicTest.Homepage"
      assert swagger_docs |> get_in([:swagger]) == "2.0"
    end

    test "works in full integration" do
      json = get_response(BasicTest.API, conn(:get, "/swagger/v1.json"))
      assert json.basePath == "/api"
      assert json.host == "myapi.com"
    end
    test "swagger info config" do

      swagger_docs =
        %ConfigStruct{
          module: MaruSwagger.ResponseFormatterTest.BasicTest.Homepage,
          info: [title: "title", description: "description"]
        } |> MaruSwagger.Plug.generate

      assert swagger_docs |> get_in([:info, :title]) == "title"
      assert swagger_docs |> get_in([:info, :description]) == "description"
      assert swagger_docs |> get_in([:swagger]) == "2.0"
    end
  end

  describe "super test" do
    defmodule SuperTest.Homepage do
      use Maru.Router
      version "v1"

      desc "hello world action"
      params do
        requires :id, type: Integer
      end
      get "/" do
        _ = params
        conn |> json(%{ hello: :world })
      end

      desc "creates res1" do
        consumes [
          "application/x-www-form-urlencoded",
          "application/json",
          "multipart/form-data"
        ]
        produces ["application/xml", "application/json"]
        operation_id "test_description"
        tags ["pets"]
        security [%{client_key: []}, %{client_platform: []}, %{client_version: []}]
        params do
          requires :name, type: String
          requires :email, type: String
        end
        post "/res1" do
          conn |> json(params)
        end
      end

      desc "creates res2" do
        consumes [
          "application/x-www-form-urlencoded",
          "application/json",
          "multipart/form-data"
        ]
        produces ["application/xml", "application/json"]
        operation_id "test_description"
        params do
          requires :name, type: String
          requires :email, type: String
        end
        post "/res2" do
          conn |> json(params)
        end
      end

    end

    defmodule SuperTest.API do
      use Maru.Router
      @make_plug true
      @test      false
      use MaruSwagger

      swagger at: "/swagger/v1.json", # (required) the mount point for the URL
              pretty: true,           # (optional) should JSON be pretty-printed?
              swagger_inject: [       # (optional) this will be directly injected into the root Swagger JSON
                host:     "myapi.com",
                basePath: "/api",
                schemes:  ["http"],
                consumes: ["application/json"],
                produces: [
                  "application/json",
                  "application/vnd.api+json"
                ],
                tags: [
                  %{
                    name: "ads",
                    description: "Ads System",
                    externalDocs: %{
                      description: "View More About Ads",
                      url: "https://github.com/gialib/maru_swagger/"
                    }
                  },
                  %{
                    name: "auth",
                    description: "Auth"
                  }
                ]
              ]

      mount MaruSwagger.ResponseFormatterTest.SuperTest.Homepage
    end

    test "includes basic information for swagger (title, API version, Swagger version)" do
      swagger_docs =
        %ConfigStruct{
          module: MaruSwagger.ResponseFormatterTest.SuperTest.Homepage,
        } |> MaruSwagger.Plug.generate


      assert swagger_docs |> get_in([:info, :title]) == "Swagger API for MaruSwagger.ResponseFormatterTest.SuperTest.Homepage"
      assert swagger_docs |> get_in([:swagger]) == "2.0"
    end

    test "works in full integration" do
      json = get_response(SuperTest.API, conn(:get, "/swagger/v1.json"))
      assert json.basePath == "/api"
      assert json.host == "myapi.com"
      assert json.schemes == ["http"]
      assert json.consumes == ["application/json"]
      assert json.produces == ["application/json", "application/vnd.api+json"]
      assert json.tags == [
        %{description: "Ads System", externalDocs: %{description: "View More About Ads", url: "https://github.com/gialib/maru_swagger/"}, name: "ads"},
        %{description: "Auth", name: "auth"}
      ]
    end

    test "swagger info config" do
      swagger_docs =
        %ConfigStruct{
          module: MaruSwagger.ResponseFormatterTest.SuperTest.Homepage,
          info: [title: "title", description: "description"]
        } |> MaruSwagger.Plug.generate

      assert swagger_docs |> get_in([:paths, "/res1", "post", :consumes]) == [
        "application/x-www-form-urlencoded",
        "application/json",
        "multipart/form-data"
      ]

      assert swagger_docs |> get_in([:paths, "/res1", "post", :produces]) == [
        "application/xml",
        "application/json"
      ]

      assert swagger_docs |> get_in([:paths, "/res1", "post", :tags]) == [
        "pets"
      ]

      assert swagger_docs |> get_in([:paths, "/res1", "post", :security]) == [
        %{client_key: []}, %{client_platform: []}, %{client_version: []}
      ]

      assert swagger_docs |> get_in([:paths, "/res2", "post", :tags]) == [
        "Version: v1"
      ]

      assert swagger_docs |> get_in([:info, :title]) == "title"
      assert swagger_docs |> get_in([:info, :description]) == "description"
      assert swagger_docs |> get_in([:swagger]) == "2.0"
    end
  end
end
