module Firebase exposing (..)

import Dict exposing (Dict)
import Json.Decode as D exposing (Decoder, Error)
import Json.Encode as E exposing (Value)
import Task exposing (Task)


type FirebaseMsg msg
    = NoOp
    | Call (Invocation msg)
    | Return ( String, Value )
    | Listen ( Packet msg )
    | StopListen String
    | PacketReceived ( String, Value )

type alias Model msg =
    { returns : List (Invocation msg)
    , subscriptions : List ( Packet msg )
    }

type alias Packet msg =
    { channel : String
    , packetDecoder : Decoder msg
    }

type alias Invocation msg =
    { callee : String
    , params : Value -- list of Value
    , returnDecoder : Decoder msg
    }

type alias FirebaseApp msg =
    { firebaseInput : (D.Value -> msg) -> Sub msg
    , firebaseOutput : Value -> Cmd msg
    , configs : Dict String String
    , toMsg : FirebaseMsg msg -> msg
    }

firebaseApp : ((Value -> msg) -> Sub msg) -> (Value -> Cmd msg) -> (FirebaseMsg msg -> msg) -> FirebaseApp msg
firebaseApp firebaseInput firebaseOutput toMsg =
    { firebaseInput = firebaseInput 
    , firebaseOutput = firebaseOutput
    , configs = Dict.empty
    , toMsg = toMsg
    }

{-
Typical use is:

  init firebaseInput firebaseOutput
  |> config
        [ ( "apiKey", "AI?????8" ),
        , ( "authDomain", "yoursubdomain.firebaseapp.com" ),
        , ( "databaseURL", "https://yoursubdomain.europe-west1.firebasedatabase.app" ),
        , ( "projectId", "YourProjectId" )
        , ( "storageBucket", "yoursubdomain.appspot.com" )
        , ( "messagingSenderId", "YOUR_MESSAGE_ID" )
        , ( "appId", "YOUR_WEB_APP_ID" )
        ]
-}
config : List ( String, String ) -> FirebaseApp msg -> FirebaseApp msg
config configurations app =
    let
        updatedConfig = Dict.fromList configurations
    in
        { app | configs = updatedConfig }


initialize : FirebaseApp msg -> Decoder msg -> Cmd msg
initialize app expectDecoder =
    let
        configValue = E.dict (String.map identity) E.string app.configs
    in
        call1 app "$$init" configValue expectDecoder


invokeJson : String -> Value -> Decoder msg -> Invocation msg
invokeJson callee params toMessage =
    Invocation callee params toMessage


listenJson : String -> Decoder msg -> Packet msg
listenJson channel toMessage =
    Packet channel toMessage


subscriptions : FirebaseApp msg -> Model msg -> Sub msg
subscriptions app model =
    app.firebaseInput (D.decodeValue decodeTaggedValue >> firebaseMsgRouter >> app.toMsg)


firebaseUpdate : FirebaseApp msg -> FirebaseMsg msg -> Model msg -> ( Model msg, Cmd msg )
firebaseUpdate app msg model =
    case msg of
        Return ( callee, value ) ->
            let
                encodedExpectation = model.returns |> List.filter (.callee >> (==) callee) |> List.head
                updatedListeners =
                    encodedExpectation
                    |> Maybe.map (\item -> model.returns |> List.filter ((/=) item ) )
                    |> Maybe.withDefault model.returns

                maybeTaskMsg = (
                    case encodedExpectation of
                        Just serialized ->
                            D.decodeValue serialized.returnDecoder value
                        Nothing ->
                            D.decodeValue (D.fail "Headache. Take aspirin!") value
                    )
                    |> Result.toMaybe
            in
            case maybeTaskMsg of
                Nothing -> ( { model | returns = updatedListeners }, Cmd.none )
                Just taskMsg_ ->
                    ( { model | returns = updatedListeners }, Task.perform (\() -> taskMsg_) ( Task.succeed () ) )
        PacketReceived ( channel, packet ) ->
            let
                encodedExpectation =
                    model.subscriptions
                    |> List.filter (.channel >> (==) channel)
                    |> List.head

                maybeTaskMsg =
                    (
                    case encodedExpectation of
                        Just serialized ->
                            D.decodeValue serialized.packetDecoder packet
                        Nothing ->
                            D.decodeValue (D.fail "Headache. Take aspirin!") packet
                    )
                    |> Result.toMaybe
            in
            case maybeTaskMsg of
                Nothing -> ( model, Cmd.none )
                Just taskMsg_ ->
                    ( model, Task.perform (\() -> taskMsg_) ( Task.succeed () ) )
        Call invocation ->
            ( { model | returns = invocation :: model.returns }
            , app.firebaseOutput ( tagCallee invocation.callee invocation.params )
            )
        Listen subscriptionMsg ->
            ( { model | subscriptions = subscriptionMsg :: model.subscriptions }, Cmd.none )
        StopListen channel ->
            ( { model
            | subscriptions = model.subscriptions
                |> List.filter (.channel >>(/=) channel )
            }, Cmd.none )
        _ ->
            ( model, Cmd.none )

expectEmpty : msg -> Decoder msg
expectEmpty msg =
    D.succeed msg

expect : ( a -> msg ) -> Decoder a -> Decoder msg
expect toMsg decoder =
    decoder |> D.andThen ( toMsg >> D.succeed )

-- Functions

listenOn : FirebaseApp msg -> String -> String -> Decoder msg -> Decoder msg -> Cmd msg
listenOn app refPath eventType expectDecoder packetDecoder =
    let
        invocationMsg : Invocation msg
        invocationMsg = -- Debug.log "listenOn [invocationMsg]"
            invokeJson "fbListenOn" ( E.list E.string [ refPath, eventType ] ) expectDecoder

        channel = refPath ++ ":" ++ eventType

        subscriptionMsg : Packet msg
        subscriptionMsg = listenJson channel packetDecoder
    in
    Cmd.batch
        [ Task.perform ( Call >> app.toMsg ) ( Task.succeed invocationMsg )
        , Task.perform ( Listen >> app.toMsg ) ( Task.succeed subscriptionMsg )
        ]

listenOff : FirebaseApp msg -> String -> Decoder msg -> Cmd msg
listenOff app channel expectDecoder =
    let
        invocationMsg : Invocation msg
        invocationMsg =
            invokeJson "fbListenOff" ( E.list E.string [ channel ] ) expectDecoder
    in
    Cmd.batch
        [ Task.perform ( StopListen >> app.toMsg ) ( Task.succeed channel )
        , Task.perform ( Call >> app.toMsg ) ( Task.succeed invocationMsg )
        ]

call : FirebaseApp msg -> String -> Decoder msg -> Cmd msg
call app fnName expectDecoder =
    let
        invocation : Invocation msg
        invocation = invokeJson fnName E.null expectDecoder
    in
    Task.perform ( Call >> app.toMsg ) ( Task.succeed invocation )

call1 : FirebaseApp msg -> String -> Value -> Decoder msg -> Cmd msg
call1 app fnName param1 expectDecoder =
    let
        invocation : Invocation msg
        invocation = invokeJson fnName ( E.list identity [ param1 ] ) expectDecoder
    in
    Task.perform (Call >> app.toMsg) (Task.succeed invocation)

call2 : FirebaseApp msg -> String -> Value -> Value -> Decoder msg -> Cmd msg
call2 app fnName param1 param2 expectDecoder =
    let
        invocation : Invocation msg
        invocation = invokeJson fnName ( E.list identity [ param1, param2 ] ) expectDecoder
    in
    Task.perform (Call >> app.toMsg) (Task.succeed invocation)

call3 : FirebaseApp msg -> String -> Value -> Value -> Value -> Decoder msg -> Cmd msg
call3 app fnName param1 param2 param3 expectDecoder =
    let
        invocation : Invocation msg
        invocation = invokeJson fnName ( E.list identity [ param1, param2, param3 ] ) expectDecoder
    in
    Task.perform (Call >> app.toMsg) (Task.succeed invocation)


-- Internal Purposes

type alias TaggedValue =
    { tag : String
    , value : Value
    }


firebaseMsgRouter : Result Error TaggedValue -> FirebaseMsg msg
firebaseMsgRouter result =
    case result of
        Err _ -> NoOp
        Ok taggedValue ->
            case taggedValue.tag of
                "$$return" ->
                    taggedValue.value
                        |> D.decodeValue decodeFunctionCallReturn
                        |> (\decoded ->
                            case decoded of
                                Ok ( callee, value ) ->
                                    Return ( callee, value )
                                Err _ -> NoOp
                            )
                "$$stream" ->
                    taggedValue.value
                        |> D.decodeValue decodePacketReceive
                        |> (\decoded ->
                            case decoded of
                                Ok ( channel, packet ) -> PacketReceived ( channel, packet )
                                Err _ -> NoOp
                        )
                _ -> NoOp


tagValue : String -> Value -> Value
tagValue tag value =
    E.object
        [ ( "tag", E.string tag )
        , ( "value", value )
        ]


tagCallee : String -> Value -> Value
tagCallee callee params =
    tagValue
        "$$call"
        ( E.object
            [ ( "callee", E.string callee )
            , ( "params", params )
            ]
        )


decodeFunctionCallReturn : Decoder ( String, Value )
decodeFunctionCallReturn =
    D.map2 (\callee value -> ( callee, value ) )
        (D.field "callee" D.string)
        (D.field "value" D.value)


decodePacketReceive : Decoder ( String, Value )
decodePacketReceive =
    D.map2 (\callee value -> ( callee, value ) )
        (D.field "channel" D.string)
        (D.field "packet" D.value)


decodeTaggedValue : Decoder TaggedValue
decodeTaggedValue =
    D.map2 TaggedValue
        (D.at ["0"] D.string)
        (D.at ["1"] D.value)
