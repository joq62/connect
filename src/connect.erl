%%%-------------------------------------------------------------------
%%% @author c50 <joq62@c50>
%%% @copyright (C) 2024, c50
%%% @doc
%%%
%%% @end
%%% Created : 29 Dec 2024 by c50 <joq62@c50>
%%%-------------------------------------------------------------------
-module(connect).

-behaviour(gen_server).
-include("connect.hrl").
-include("log.api").
%% API

-export([
	 update/0,
	 connect_status/0
	]).
-export([ping/0,
	 start_link/0
	]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

-define(SERVER, ?MODULE).
-define(LoopTime,30*1000).
-record(state, {
	       connect_status
	       }).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Used to check if the application has started correct
%% @end
%%--------------------------------------------------------------------
-spec connect_status() -> ConnectStatus::term().
connect_status()-> 
    gen_server:call(?SERVER, {connect_status},infinity).
%%--------------------------------------------------------------------
%% @doc
%% Used to check if the application has started correct
%% @end
%%--------------------------------------------------------------------
-spec update() -> ok.
update()-> 
    gen_server:cast(?SERVER, {update}).


%%--------------------------------------------------------------------
%% @doc
%% Ping
%% @end
%%--------------------------------------------------------------------
-spec ping() -> pong.

ping() ->
    gen_server:call(?SERVER,{ping},infinity).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid :: pid()} |
	  {error, Error :: {already_started, pid()}} |
	  {error, Error :: term()} |
	  ignore.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
	  {ok, State :: term(), Timeout :: timeout()} |
	  {ok, State :: term(), hibernate} |
	  {stop, Reason :: term()} |
	  ignore.
init([]) ->
    process_flag(trap_exit, true),
    MyNode=node(),
    ConnectStatus=[{N,net_kernel:connect_node(N)}||N<-?ConnectNodes,
						  N /= MyNode],
    
    spawn(fun()->loop() end),
    {ok, #state{
	   connect_status=ConnectStatus
	   }}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request :: term(), From :: {pid(), term()}, State :: term()) ->
	  {reply, Reply :: term(), NewState :: term()} |
	  {reply, Reply :: term(), NewState :: term(), Timeout :: timeout()} |
	  {reply, Reply :: term(), NewState :: term(), hibernate} |
	  {noreply, NewState :: term()} |
	  {noreply, NewState :: term(), Timeout :: timeout()} |
	  {noreply, NewState :: term(), hibernate} |
	  {stop, Reason :: term(), Reply :: term(), NewState :: term()} |
	  {stop, Reason :: term(), NewState :: term()}.
handle_call({connect_status}, _From, State) ->
    Reply=State#state.connect_status,
    {reply, Reply, State};


handle_call({ping}, _From, State) ->
    Reply = pong,
    {reply, Reply, State};

handle_call(UnMatchedSignal, From, State) ->
   ?LOG_WARNING("Unmatched signal",[UnMatchedSignal]),
    io:format("unmatched_signal ~p~n",[{UnMatchedSignal, From,?MODULE,?LINE}]),
    Reply = {error,[unmatched_signal,UnMatchedSignal, From]},
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request :: term(), State :: term()) ->
	  {noreply, NewState :: term()} |
	  {noreply, NewState :: term(), Timeout :: timeout()} |
	  {noreply, NewState :: term(), hibernate} |
	  {stop, Reason :: term(), NewState :: term()}.

handle_cast({update}, State) ->
    NewConnect=[{N,net_kernel:connect_node(N)}||N<-?ConnectNodes],
    NewConnectStatus=[N||{N,true}<-NewConnect],
    LenNew=erlang:length(NewConnectStatus),
    LenPrevious=erlang:length(State#state.connect_status),
    if
	LenPrevious=:=LenNew->
	    ok;
	LenNew>LenPrevious-> % New nodes added
	    AddedNodes=[N||N<-NewConnectStatus,
			   false=:=lists:member(N,State#state.connect_status)],
	    ?LOG_NOTICE("Nodes added ",[AddedNodes]);
	LenNew<LenPrevious-> %Removed nodes
	    RemovedNodes=[N||N<-State#state.connect_status,
					    false=:=lists:member(N,NewConnectStatus)],
	    ?LOG_NOTICE("Nodes removed ",[RemovedNodes])
		
    end,
    if
	LenPrevious=:=LenNew->
	    ?LOG_NOTICE("Connected Nodes ",[NewConnectStatus]);
	  %  io:format("Updated imported ~p~n",[{?MODULE,?FUNCTION_NAME,?LINE,NewImportedList}]);
	true->
	    ok
    end,
    NewState=State#state{connect_status=NewConnectStatus},
    spawn(fun()->loop() end),
    {noreply, NewState};

handle_cast(_Request, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info :: timeout() | term(), State :: term()) ->
	  {noreply, NewState :: term()} |
	  {noreply, NewState :: term(), Timeout :: timeout()} |
	  {noreply, NewState :: term(), hibernate} |
	  {stop, Reason :: normal | term(), NewState :: term()}.
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason :: normal | shutdown | {shutdown, term()} | term(),
		State :: term()) -> any().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn :: term() | {down, term()},
		  State :: term(),
		  Extra :: term()) -> {ok, NewState :: term()} |
	  {error, Reason :: term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called for changing the form and appearance
%% of gen_server status when it is returned from sys:get_status/1,2
%% or when it appears in termination error logs.
%% @end
%%--------------------------------------------------------------------
-spec format_status(Opt :: normal | terminate,
		    Status :: list()) -> Status :: term().
format_status(_Opt, Status) ->
    Status.

%%%===================================================================
%%% Internal functions
%%%===================================================================
loop()->
    timer:sleep(?LoopTime),
    rpc:cast(node(),?MODULE,update,[]).
