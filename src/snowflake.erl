% @author Joseph Abrahamson <me@jspha.com>
%% @copyright 2012 Joseph Abrahamson

%% @doc Snowflake, a distributed Erlang 64bit UUID server. Based on
%% the Twitter project of the same name.

-module(snowflake).

-author('Joseph Abrahamson <me@jspha.com>').

-behaviour(gen_server).

%% Public API
-export([new/0, new/1]).
% -export([request/0, request/1, await/0, await/1]).
-export([start_link/0, start/0]).

%% Behaviour API
-export([init/1, terminate/2, handle_info/2, code_change/3]).
-export([handle_call/3, handle_cast/2]).

%% Private API
-define(SNOWFLAKE_EPOCH,
	calendar:datetime_to_gregorian_seconds({{2012, 1, 1}, {0,0,0}})).
-define(STD_EPOCH,
	calendar:datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})).
-define(MS_EPOCH_DIFF, 1000*(?SNOWFLAKE_EPOCH - ?STD_EPOCH)).

-record(snowflake_state, 
	{last :: integer(),
	 machine :: integer(),
	 sequence :: integer()}).

% -type snowflake_state() :: #snowflake_state{}.

%% --------------
%% Initialization

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start() ->
    gen_server:start({local, ?MODULE}, ?MODULE, [], []).

%% ----------
%% Public API

-type uuid() :: <<_:64>>.
%% A uuid binary consisting of `<<Time, MachineID, SequenceID>>' where
%% `Time' is a 42 bit binary integer recording milliseconds since UTC
%% 2012-01-01T00:00:00Z, `MachineID' a 10 bit integer recording the
%% snowflake machine which generated the said UUID, and `SequenceID'
%% is a 12 bit integer counting the number of UUIDs generated on this
%% server, this millisecond.

-spec 
%% @equiv new(default).
new() -> uuid().
new() ->
    new(default).

-spec 
%% @doc Synchronously returns a new snowflake `uuid()'.
new(Class :: atom()) -> uuid().
new(Class) ->
    gen_server:call(?MODULE, {new, Class}).

%% TODO: Add asynchronous snowflake requesting?

%% -----------------
%% Callback handling

handle_call({new, Class}, _From, 
	    State = #snowflake_state{last = Last, 
				     machine = MID, 
				     sequence = SID}) ->
    Now = snowflake_now(),
    case Now of
	Last -> 
	    {reply, 
	     <<Now:42, MID:10, SID:12>>, 
	     State#snowflake_state{sequence = SID + 1}};
	_ -> 
	    {reply,
	     <<Now:42, MID:10, SID:12>>,
	     State#snowflake_state{last = Now, sequence = 0}}
    end.

handle_cast(_Message, State) ->
    {noreply, State}.

%% ----------------
%% Server framework

init(_Args) ->
    State0 = #snowflake_state{last = snowflake_now(),
			      sequence = 0,
			      machine = 0},
    case application:get_env(machine_id) of
	undefined -> {ok, State0};
	{ok, Number} -> {ok, State0#snowflake_state{machine = Number}}
    end.

terminate(normal, _State) ->
    ok.

handle_info(_Message, State) ->
    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ---------
%% Utilities

%% @doc returns the number of milliseconds since UTC January 1st,
%% 2012.
snowflake_now() ->
    {MegS, S, MuS} = erlang:now(),
    Secs = (1000000*MegS + S)*1000 + trunc(MuS/1000),
    Secs - ?MS_EPOCH_DIFF.
