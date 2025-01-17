%%--------------------------------------------------------------------
%% Copyright (c) 2020-2023 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(emqx_conf_cli).
-export([
    load/0,
    admins/1,
    conf/1,
    unload/0
]).

-define(CLUSTER_CALL, cluster_call).
-define(CONF, conf).

load() ->
    emqx_ctl:register_command(?CLUSTER_CALL, {?MODULE, admins}, []),
    emqx_ctl:register_command(?CONF, {?MODULE, conf}, []).

unload() ->
    emqx_ctl:unregister_command(?CLUSTER_CALL),
    emqx_ctl:unregister_command(?CONF).

conf(["show", "--keys-only"]) ->
    print(emqx_config:get_root_names());
conf(["show"]) ->
    print_hocon(get_config());
conf(["show", Key]) ->
    print_hocon(get_config(Key));
conf(["load", Path]) ->
    load_config(Path);
conf(_) ->
    emqx_ctl:usage(
        [
            %% TODO add reload
            %{"conf reload", "reload etc/emqx.conf on local node"},
            {"conf show --keys-only", "print all keys"},
            {"conf show", "print all running configures"},
            {"conf show <key>", "print a specific configuration"},
            {"conf load <path>", "load a hocon file to all nodes"}
        ]
    ).

admins(["status"]) ->
    status();
admins(["skip"]) ->
    status(),
    Nodes = mria:running_nodes(),
    lists:foreach(fun emqx_cluster_rpc:skip_failed_commit/1, Nodes),
    status();
admins(["skip", Node0]) ->
    status(),
    Node = list_to_existing_atom(Node0),
    emqx_cluster_rpc:skip_failed_commit(Node),
    status();
admins(["tnxid", TnxId0]) ->
    TnxId = list_to_integer(TnxId0),
    print(emqx_cluster_rpc:query(TnxId));
admins(["fast_forward"]) ->
    status(),
    Nodes = mria:running_nodes(),
    TnxId = emqx_cluster_rpc:latest_tnx_id(),
    lists:foreach(fun(N) -> emqx_cluster_rpc:fast_forward_to_commit(N, TnxId) end, Nodes),
    status();
admins(["fast_forward", ToTnxId]) ->
    status(),
    Nodes = mria:running_nodes(),
    TnxId = list_to_integer(ToTnxId),
    lists:foreach(fun(N) -> emqx_cluster_rpc:fast_forward_to_commit(N, TnxId) end, Nodes),
    status();
admins(["fast_forward", Node0, ToTnxId]) ->
    status(),
    TnxId = list_to_integer(ToTnxId),
    Node = list_to_existing_atom(Node0),
    emqx_cluster_rpc:fast_forward_to_commit(Node, TnxId),
    status();
admins(_) ->
    emqx_ctl:usage(
        [
            {"cluster_call status", "status"},
            {"cluster_call skip [node]", "increase one commit on specific node"},
            {"cluster_call tnxid <TnxId>", "get detailed about TnxId"},
            {"cluster_call fast_forward [node] [tnx_id]", "fast forwards to tnx_id"}
        ]
    ).

status() ->
    emqx_ctl:print("-----------------------------------------------\n"),
    {atomic, Status} = emqx_cluster_rpc:status(),
    lists:foreach(
        fun(S) ->
            #{
                node := Node,
                tnx_id := TnxId,
                mfa := {M, F, A},
                created_at := CreatedAt
            } = S,
            emqx_ctl:print(
                "~p:[~w] CreatedAt:~p ~p:~p/~w\n",
                [Node, TnxId, CreatedAt, M, F, length(A)]
            )
        end,
        Status
    ),
    emqx_ctl:print("-----------------------------------------------\n").

print(Json) ->
    emqx_ctl:print("~ts~n", [emqx_logger_jsonfmt:best_effort_json(Json)]).

print_hocon(Hocon) ->
    emqx_ctl:print("~ts~n", [hocon_pp:do(Hocon, #{})]).

get_config() -> emqx_config:fill_defaults(emqx:get_raw_config([])).
get_config(Key) -> emqx_config:fill_defaults(#{Key => emqx:get_raw_config([Key])}).

-define(OPTIONS, #{rawconf_with_defaults => true, override_to => cluster}).
load_config(Path) ->
    case hocon:files([Path]) of
        {ok, Conf} ->
            maps:foreach(
                fun(Key, Value) ->
                    case emqx_conf:update([Key], Value, ?OPTIONS) of
                        {ok, _} -> emqx_ctl:print("load ~ts ok~n", [Key]);
                        {error, Reason} -> emqx_ctl:print("load ~ts failed: ~p~n", [Key, Reason])
                    end
                end,
                Conf
            );
        {error, Reason} ->
            emqx_ctl:print("load ~ts failed~n~p~n", [Path, Reason]),
            {error, bad_hocon_file}
    end.
