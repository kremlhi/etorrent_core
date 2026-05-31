-module(etorrent_rlimit).
%% No-op rate-limiter stub.
%%
%% The original implementation delegated to the abandoned `rlimit` application
%% (arcusfelis/rlimit).  Until a replacement token-bucket limiter is written,
%% every slot is granted immediately: send/1 and recv/1 fire {rlimit, continue}
%% back to the caller with no delay, preserving the existing callback contract
%% in etorrent_peer_send and etorrent_peer_recv without requiring callers to
%% change.
%%
%% Rate queries return 0 and rate setters are no-ops.
-export([init/0,
         send/1,
         recv/1,
         send_rate/0,
         recv_rate/0,
         max_send_rate/0,
         max_recv_rate/0,
         max_send_rate/1,
         max_recv_rate/1]).

-spec init() -> ok.
init() -> ok.

%% @doc Grant a send slot immediately.
%% Sends {rlimit, continue} to the calling process and returns self() as a
%% stand-in for the limiter pid expected by etorrent_peer_send.
-spec send(non_neg_integer()) -> pid().
send(_Bytes) ->
    self() ! {rlimit, continue},
    self().

%% @doc Grant a receive slot immediately.
-spec recv(non_neg_integer()) -> pid().
recv(_Bytes) ->
    self() ! {rlimit, continue},
    self().

-spec send_rate() -> non_neg_integer().
send_rate() -> 0.

-spec recv_rate() -> non_neg_integer().
recv_rate() -> 0.

-spec max_send_rate() -> non_neg_integer().
max_send_rate() -> 0.

-spec max_recv_rate() -> non_neg_integer().
max_recv_rate() -> 0.

-spec max_send_rate(non_neg_integer()) -> ok.
max_send_rate(_Value) -> ok.

-spec max_recv_rate(non_neg_integer()) -> ok.
max_recv_rate(_Value) -> ok.
