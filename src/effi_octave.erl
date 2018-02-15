%% -*- erlang -*-
%%
%% Erlang foreign function interface.
%%
%% Copyright 2015-2018 Jörgen Brandt
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%    http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% -------------------------------------------------------------------
%% @author Jörgen Brandt <joergen.brandt@onlinehome.de>
%% @version 0.1.4
%% @copyright 2015-2018 Jörgen Brandt
%%
%% @doc The standalone application entry point is {@link main/1}. 
%% The create_port callback defined here is an abstract way to execute child 
%% processes in foreign languages. 
%% There are two foreign language interfaces, both implementing this callback,
%% {@link effi_script} (e.g., Perl, Python) and {@link effi_interact} (e.g.,
%% Bash, R).
%%
%% @end
%% -------------------------------------------------------------------

-module( effi_octave ).

-behaviour( effi ).

%%====================================================================
%% Exports
%%====================================================================

% effi callbacks
-export( [get_extended_script/4, run_extended_script/2] ).


%%====================================================================
%% Includes
%%====================================================================

-include( "effi.hrl" ).

%%====================================================================
%% Effi callback function implementations
%%====================================================================

-spec get_extended_script( ArgTypeLst, RetTypeLst, Script, ArgBindLst ) ->
        binary()
when ArgTypeLst :: [#{ atom() => _ }],
     RetTypeLst :: [#{ atom() => _ }],
     Script     :: binary(),
     ArgBindLst :: [#{ atom() => _ }].

get_extended_script( ArgTypeLst, RetTypeLst, Script, ArgBindLst )
when is_list( ArgTypeLst ),
     is_list( RetTypeLst ),
     is_binary( Script ),
     is_list( ArgBindLst ) ->

  Bind =
    fun( #{ arg_name := ArgName, value := Value }, B ) ->

      TypeInfo = effi:get_type_info( ArgName, ArgTypeLst ),
      #{ arg_type := ArgType, is_list := IsList } = TypeInfo,

      X = 
        case IsList of

          false ->
            case ArgType of

              <<"Bool">> ->
                bind_singleton_boolean( ArgName, Value );
  
              T when T =:= <<"Str">> orelse T =:= <<"File">> ->
                bind_singleton_string( ArgName, Value )

            end;

          true ->
            case ArgType of

              <<"Bool">> ->
                bind_boolean_list( ArgName, Value );

              T when T =:= <<"Str">> orelse T =:= <<"File">> ->
                bind_string_list( ArgName, Value )

            end

        end,

      <<B/binary, X/binary>>
    end,

  Echo =
    fun( TypeInfo, B ) ->

      #{ arg_name := ArgName, arg_type := ArgType, is_list := IsList } = TypeInfo,

      X =
        case IsList of

          false ->
            case ArgType of

              <<"Bool">> ->
                echo_singleton_boolean( ArgName );

              T when T =:= <<"Str">> orelse T =:= <<"File">> ->
                echo_singleton_string( ArgName )

            end;

          true ->
            case ArgType of

              <<"Bool">> ->
                echo_boolean_list( ArgName );

              T when T =:= <<"Str">> orelse T =:= <<"File">> ->
                echo_string_list( ArgName )

            end

        end,

      <<B/binary, X/binary>>

    end,

  Binding = lists:foldl( Bind, <<>>, ArgBindLst ),
  Echoing = lists:foldl( Echo, <<>>, RetTypeLst ),
  EndOfTransmission = <<"display( '", ?EOT, "' )\n">>,

  <<"try\n", "\n",
    Binding/binary, "\n",
    Script/binary, "\n",
    Echoing/binary, "\n",
    EndOfTransmission/binary, "\n",
    "catch e\n  exit( -1 );\nend\n">>.


-spec run_extended_script( ExtendedScript, Dir ) ->
          {ok, binary(), [#{ atom() => _ }]}
        | {error, binary()}
when ExtendedScript :: binary(),
     Dir            :: string().

run_extended_script( ExtendedScript, Dir )
when is_binary( ExtendedScript ),
     is_list( Dir ) ->

  ScriptFile = string:join( [Dir, "__script.m"], "/" ),
  Call = "octave __script.m",

  ok = file:write_file( ScriptFile, ExtendedScript ),

  Port = effi:create_port( Call, Dir ),

  effi:listen_port( Port ).


%%====================================================================
%% Internal functions
%%====================================================================

-spec bind_singleton_string( ArgName, Value ) -> binary()
when ArgName :: binary(),
     Value   :: binary().

bind_singleton_string( ArgName, Value )
when is_binary( ArgName ),
     is_binary( Value ) ->

  <<ArgName/binary, " = '", Value/binary, "';\n">>.

-spec bind_singleton_boolean( ArgName, Value ) -> binary()
when ArgName :: binary(),
     Value   :: binary().

bind_singleton_boolean( ArgName, <<"true">> ) ->
  <<ArgName/binary, " = true;\n">>;

bind_singleton_boolean( ArgName, <<"false">> ) ->
  <<ArgName/binary, " = false;\n">>.

-spec bind_boolean_list( ArgName, Value ) -> binary()
when ArgName :: binary(),
     Value   :: [binary()].

bind_boolean_list( ArgName, Value )
when is_binary( ArgName ),
     is_list( Value ) ->

  StrLst = lists:map( fun binary_to_list/1, Value ),
  B = list_to_binary( "{"++string:join( StrLst, ", " )++"}" ),
  <<ArgName/binary, " = ", B/binary, ";\n">>.


-spec bind_string_list( ArgName, Value ) -> binary()
when ArgName :: binary(),
     Value   :: [binary()].

bind_string_list( ArgName, Value )
when is_binary( ArgName ),
     is_list( Value ) ->

  StrLst = ["'"++binary_to_list( V )++"'" || V <- Value],
  B = list_to_binary( "{"++string:join( StrLst, ", " )++"}" ),
  <<ArgName/binary, " = ", B/binary, ";\n">>.


-spec echo_singleton_string( ArgName :: binary() ) -> binary().

echo_singleton_string( ArgName )
when is_binary( ArgName ) ->

  <<"if ~ischar( ", ArgName/binary, " )\n",
    "  error( '", ArgName/binary, " not a string' )\n",
    "end\n",
    "display( ['", ?MSG, "{\"arg_name\":\"", ArgName/binary,
    "\",\"value\":\"', ", ArgName/binary, ", '\"}\\n'] )\n\n">>.


echo_singleton_boolean( ArgName )
when is_binary( ArgName ) ->

  <<"if ~islogical( ", ArgName/binary, " )\n",
    "  error( '", ArgName/binary, " not a logical' )\n",
    "end\n",
    "if ", ArgName/binary, "\n",
    "  display( '", ?MSG, "{\"arg_name\":\"", ArgName/binary,
    "\",\"value\":\"true\"}\\n' )\n",
    "else\n",
    "  display( '", ?MSG, "{\"arg_name\":\"", ArgName/binary,
    "\",\"value\":\"false\"}\\n' )\n",
    "end\n\n">>.


-spec echo_string_list( ArgName :: binary() ) -> binary().

echo_string_list( ArgName )
when is_binary( ArgName ) ->

  <<"if ~iscell( ", ArgName/binary, " )\n",
    "  error( '", ArgName/binary, " not a cell' )\n",
    "end\n",
    "for i = 1:prod( size( ", ArgName/binary, " ) )\n",
    "  if ~ischar( ", ArgName/binary, "{ i } )\n",
    "    error( '", ArgName/binary, " contains non-string elements' )\n",
    "  end\n",
    "end\n",
    "printf( '", ?MSG, "{\"arg_name\":\"", ArgName/binary,
    "\",\"value\":[' )\n",
    "for i = 1:prod( size( ", ArgName/binary, " ) )\n",
    "  if i ~= 1\n",
    "    printf( ',' )\n",
    "  end\n",
    "  printf( '\"%s\"', ", ArgName/binary, "{ i } )\n",
    "end\n",
    "printf( ']}\\n' )\n\n">>.


-spec echo_boolean_list( ArgName :: binary() ) -> binary().

echo_boolean_list( ArgName ) ->

  <<"if ~iscell( ", ArgName/binary, " )\n",
    "  error( '", ArgName/binary, " not a cell' )\n",
    "end\n",
    "for i = 1:prod( size( ", ArgName/binary, " ) )\n",
    "  if ~islogical( ", ArgName/binary, "{ i } )\n",
    "    error( '", ArgName/binary, " contains non-logical elements' )\n",
    "  end\n",
    "end\n",
    "printf( '", ?MSG, "{\"arg_name\":\"", ArgName/binary,
    "\",\"value\":[' )\n",
    "for i = 1:prod( size( ", ArgName/binary, " ) )\n",
    "  if i ~= 1\n",
    "    printf( ',' )\n",
    "  end\n",
    "  if ", ArgName/binary, "\n",
    "    printf( '\"true\"' )\n",
    "  else\n",
    "    printf( '\"false\"' )\n",
    "  end\n",
    "end\n",
    "printf( ']}\\n' )\n\n">>.

