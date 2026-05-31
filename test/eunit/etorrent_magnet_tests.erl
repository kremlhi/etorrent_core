%% Tests for the mochiweb_util → uri_string migration in etorrent_magnet.
-module(etorrent_magnet_tests).
-include_lib("eunit/include/eunit.hrl").

encode_space_test() ->
    Url = etorrent_magnet:build_url(16#AABBCCDD, <<"My Torrent">>, []),
    ?assertMatch(nomatch, binary:match(Url, <<" ">>)).

encode_tracker_chars_test() ->
    Url = etorrent_magnet:build_url(
            16#AABBCCDD, undefined,
            ["http://tracker.example.com/announce?foo=bar&baz=qux"]),
    [_Prefix, TrPart] = binary:split(Url, <<"&tr=">>),
    ?assertMatch(nomatch, binary:match(TrPart, <<"?">>)),
    ?assertMatch(nomatch, binary:match(TrPart, <<"&">>)).

uri_string_quote_test() ->
    Bin = iolist_to_binary(uri_string:quote(<<"hello world">>)),
    ?assertMatch(nomatch,  binary:match(Bin, <<" ">>)),
    ?assertMatch({_, _},   binary:match(Bin, <<"hello">>)).
