%%--------------------------------------------------------------------
%% Copyright (c) 2020-2021 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------
-module(emqx_auto_subscribe_schema).

-behaviour(hocon_schema).

-include_lib("typerefl/include/types.hrl").

-export([ roots/0
        , fields/1]).

roots() ->
    ["auto_subscribe"].

fields("auto_subscribe") ->
    [ {topics, hoconsc:array(hoconsc:ref(?MODULE, "topic"))}];

fields("topic") ->
    [ {topic, emqx_schema:t(binary())}
    , {qos, t(hoconsc:union([0, 1, 2]), 0)}
    , {rh,  t(hoconsc:union([0, 1, 2]), 0)}
    , {rap, t(hoconsc:union([0, 1]), 0)}
    , {nl,  t(hoconsc:union([0, 1]), 0)}
    ].

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------
t(Type, Default) ->
    hoconsc:t(Type, #{default => Default}).
