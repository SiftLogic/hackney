-module(hackney_pool_checkout_tests).
-include_lib("eunit/include/eunit.hrl").
-include("hackney_lib.hrl").

%% This seems necessary to list the tests including the generator
dummy_test() ->
    ?assertEqual(ok, ok).

multipart_test_() ->
    {setup, fun start/0, fun stop/1,
      [checkout_timeout()]}.

start() ->
    error_logger:tty(false),
    {ok, _} = application:ensure_all_started(cowboy),
    {ok, _} = application:ensure_all_started(hackney),
    hackney_pool:start_pool(pool_test, [{pool_size, 1}]),
    Host = '_',
    Resource = {"/pool", pool_resource, []},
    Dispatch = cowboy_router:compile([{Host, [Resource]}]),
    cowboy:start_http(test_server, 10, [{port, 8123}], [{env, [{dispatch, Dispatch}]}]).

stop({ok, _Pid}) ->
    cowboy:stop_listener(test_server),
    application:stop(cowboy),
    hackney_pool:stop_pool(pool_test),
    application:stop(hackney),
    error_logger:tty(true),
    ok.

checkout_timeout() ->
    fun() ->
        URL = <<"http://localhost:8123/pool">>,
        Headers = [],
        Opts = [{pool, pool_test}, {connect_timeout, 1000}, {checkout_timeout, 100}],
        case hackney:request(post, URL, Headers, stream, Opts) of
            {ok, Ref} ->
                {error, Error} = hackney:request(post, URL, Headers, stream, Opts),
                ?assertEqual(Error, checkout_timeout),
                ok = hackney:finish_send_body(Ref),
                {ok, _Status, _Headers, Ref} = hackney:start_response(Ref),
                ok = hackney:skip_body(Ref),
                {ok, _} = hackney:request(post, URL, Headers, stream, Opts)
        end
    end.
