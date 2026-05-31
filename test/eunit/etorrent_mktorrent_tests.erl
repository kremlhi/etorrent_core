%% Tests that etorrent_mktorrent uses crypto:hash(sha, ...) correctly
%% (formerly crypto:sha/1, removed in OTP 26).
-module(etorrent_mktorrent_tests).
-include_lib("eunit/include/eunit.hrl").

create_test_() ->
    Dir = filename:join(os:getenv("TMPDIR", "/tmp"), "etorrent_mktorrent_tests"),
    {setup,
     fun() ->
         ok = filelib:ensure_dir(Dir ++ "/"),
         Dir
     end,
     fun(_) -> ok end,
     fun(D) ->
         DataFile    = filename:join(D, "data.bin"),
         TorrentFile = filename:join(D, "out.torrent"),
         Data = <<"hello from mktorrent eunit test">>,
         ok = file:write_file(DataFile, Data),
         ok = etorrent_mktorrent:create(DataFile,
                                        "http://tracker.example.com/announce",
                                        TorrentFile),
         {ok, Enc} = file:read_file(TorrentFile),
         {ok, Dec} = etorrent_bcoding:decode(Enc),
         Info   = proplists:get_value(<<"info">>, Dec),
         Pieces = proplists:get_value(<<"pieces">>, Info),
         [?_assert(is_binary(Pieces)),
          ?_assertEqual(0, byte_size(Pieces) rem 20),
          ?_assertEqual(20, byte_size(Pieces)),
          ?_assertEqual(crypto:hash(sha, Data), Pieces)]
     end}.
