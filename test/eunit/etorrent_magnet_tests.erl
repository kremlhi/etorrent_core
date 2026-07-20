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

colton_url() ->
    "magnet:?xt=urn:btih:b48ed25b01668963e1f0ff782be383c5e7060eb4&"
    "dn=Jonathan+Coulton+-+Discography&"
    "tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A80&"
    "tr=udp%3A%2F%2Ftracker.publicbt.com%3A80&"
    "tr=udp%3A%2F%2Ftracker.istole.it%3A6969&"
    "tr=udp%3A%2F%2Ftracker.ccc.de%3A80".

parse_url_test_() ->
    [?_assertEqual({398417223648295740807581630131068684170926268560, undefined, []},
                   etorrent_magnet:parse_url("magnet:?xt=urn:btih:IXE2K3JMCPUZWTW3YQZZOIB5XD6KZIEQ"))
    ,?_assertEqual({1030803369114085151184244669493103882218552823476,
                                   "Jonathan Coulton - Discography",
                                   %% Trackers come back in URL order.
                                   ["udp://tracker.openbittorrent.com:80",
                                    "udp://tracker.publicbt.com:80",
                                    "udp://tracker.istole.it:6969",
                                    "udp://tracker.ccc.de:80"]},
                   etorrent_magnet:parse_url(colton_url()))
    ].
