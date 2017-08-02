%% -*- erlang -*-
%%
%% Cuneiform: A Functional Language for Large Scale Scientific Data Analysis
%%
%% Copyright 2016 Jörgen Brandt, Marc Bux, and Ulf Leser
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

%% @author Jorgen Brandt <brandjoe@hu-berlin.de>


-module( effi_bash ).
-author( "Jorgen Brandt <brandjoe@hu-berlin.de>" ).

-behaviour( effi_lang ).


-include( "effi.hrl" ).

%% ------------------------------------------------------------
%% Callback exports
%% ------------------------------------------------------------

-export( [create_port/2, assignment/3, dismissal/2, process/1, prefix/0,
          suffix/0] ).


%% ------------------------------------------------------------
%% Callback functions
%% ------------------------------------------------------------


create_port( Script, Dir )
when is_binary( Script ),
     is_list( Dir ) ->
  effi_port:create_interact_port( Script, Dir, "bash" ).


prefix() -> <<"set -eu -o pipefail">>.


suffix() -> <<"exit">>.

assignment( Name, false, [Value] )
when is_binary( Name ),
     is_binary( Value ) ->
  <<Name/binary, $=, $", Value/binary, $" , $\n>>;

assignment( Name, true, ValueLst )
when is_binary( Name ),
     is_list( ValueLst ) ->
  X = list_to_binary( string:join( [[$", V, $"] || V <- ValueLst], " " ) ),
  <<Name/binary, "=(", X/binary, ")\n">>.

dismissal( OutName, false )
when is_binary( OutName ) ->
  <<"echo \"", ?MSG, "{\\\"", OutName/binary, "\\\":[\\\"$", OutName/binary,
    "\\\"]}.\"\n">>;

dismissal( OutName, true )
when is_binary( OutName ) ->
  <<"TMP=`printf \",\\\"%s\\\"\" ${", OutName/binary,
    "[@]}`\nTMP=${TMP:1}\necho \"", ?MSG, "{\\\"", OutName/binary,
    "\\\":[$TMP]}.\"\n">>.

process( Script ) -> binary:replace( Script, <<$\r>>, <<"">>, [global] ).

