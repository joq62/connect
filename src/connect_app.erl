%%%-------------------------------------------------------------------
%% @doc connect public API
%% @end
%%%-------------------------------------------------------------------

-module(connect_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    connect_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
