port module Main exposing (main)

import Browser exposing (Document)
import Html exposing (Html, button, div, form, h1, h2, h3, input, label, p, text, textarea)
import Firebase as F
import Html.Attributes exposing (class, for, placeholder, style, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Json.Decode as D exposing (Value, string)
import Json.Encode as E

port firebaseInput : (Value -> msg) -> Sub msg
port firebaseOutput : Value -> Cmd msg

main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , subscriptions = subscriptions
        , update = update
        }


type alias Model =
    { initialized : Bool
    , username : String
    , password : String
    , currentUser : Maybe Profile
    , newMessage : String
    , chatMessages : List String
    , fbModel : F.Model Msg
    }


type alias Profile =
    { uid : String
    , anonymous: Bool
    , displayName : Maybe String
    }


type Msg
    = FirebaseInitialized
    | SetFormValue String String
    | Login String String
    | DidLogin Profile
    | FB ( F.FirebaseMsg Msg )
    | SendMessage String
    | DidSendMessage
    | DidListenMessages
    | GotMessage String
    | GotMessages ( List String )


fbApp = F.firebaseApp firebaseInput firebaseOutput FB
    |> F.config [ ( "apiKey", "AIzaSyBB6mJ8zC4HeqpnznHVnrqvu7vq3i05HQU" )
                , ( "authDomain", "tictactoe-7d2d5.firebaseapp.com" )
                , ( "projectId", "tictactoe-7d2d5" )
                , ( "storageBucket", "tictactoe-7d2d5.appspot.com")
                , ( "messagingSenderId", "1060266018339" )
                , ( "appId", "1:1060266018339:web:c3a29cb4f0361ab8435396" )
                , ( "databaseURL", "https://tictactoe-7d2d5-default-rtdb.europe-west1.firebasedatabase.app/" )
                ]


init : () -> ( Model, Cmd Msg )
init () =
    (   { initialized = False
        , currentUser = Nothing
        , chatMessages = []
        , newMessage = ""
        , fbModel = F.init fbApp
        , username = ""
        , password = ""
        }
    , F.initialize fbApp (F.expectEmpty FirebaseInitialized)
    )


view : Model -> Document Msg
view model =
    { title = "Chat App - Demo"
    , body =
        [ div [ class "container" ]
            [  div [ class "row" ]
                [  div [ class "col" ] [ h1 [] [ text "Chat App" ] ]
                ]
            , if not model.initialized
                then div [ class "row" ] [ div [ class "col" ] [ p [] [ text "Initializing..." ] ]]
                else if model.currentUser == Nothing
                    then loginView model
                    else chatView model

            ]
        ]
    }


loginView : Model -> Html Msg
loginView model =
    div [ class "row" ]
        [ div [ class "col-5" ]
            [ h2 [] [ text "Login" ]
            , form [ class "form", onSubmit (Login model.username model.password ) ]
                [ div [ class "mb-3" ]
                    [ label [ for "username" ] [ text "Username" ]
                    , input
                        [ type_ "email"
                        , class "form-control"
                        , placeholder "user.name@gmail.com"
                        , onInput ( SetFormValue "username" )
                        , value model.username
                        ] []
                    ]
                ,  div [ class "mb-3" ]
                    [ label [ for "password" ] [ text "Password" ]
                    , input
                        [ type_ "password"
                        , class "form-control"
                        , placeholder "****************"
                        , onInput ( SetFormValue "password" )
                        , value model.password
                        ] []
                    ]
                , div [ class "mb-3"]
                    [ button
                        [ type_ "submit"
                        , class "btn btn-primary"
                        ] [ text "Sign in" ]
                    ]
                ]
            ]
        ]


chatView : Model -> Html Msg
chatView model =
    div [ class "row" ]
        [ div [ class "col-5" ]
            [ h3 []
                [ text ("Welcome " ++
                    ( model.currentUser
                        |> Maybe.map .uid
                        |> Maybe.withDefault "?" )
                    )
                ]
            , p [] [ text "Your message:" ]
            , textarea [ class "form-control mb-2", value model.newMessage, onInput ( SetFormValue "newMessage" ) ] []
            , button [ class "btn btn-primary", onClick ( SendMessage model.newMessage )]
                [ text "Send"
                ]
            ]
        , div [ class "col-7" ]
            ( model.chatMessages
                |> List.map (\message ->
                    div [ class "p-2 mb-2 border border-info", style "border-radius" "0.5rem" ]
                        <| List.singleton
                        <| p [] [ text message ]
                )
            )
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
     F.subscriptions fbApp model.fbModel


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FirebaseInitialized ->
            ( { model
                | initialized = True
                }
           , Cmd.none)
        SetFormValue formField value ->
            if formField == "username" then
                ( { model | username = value }, Cmd.none )
            else if formField == "password" then
                ( { model | password = value }, Cmd.none )
            else if formField == "newMessage" then
                ( { model | newMessage = value }, Cmd.none )
            else
                ( model, Cmd.none )
        Login username password ->
            ( model, F.call2 fbApp "fbLogin"
                ( E.string username )
                ( E.string password )
                ( F.expect DidLogin
                    ( D.map2
                        (\uid displayName -> Profile uid False displayName )
                        ( D.field "uid" D.string )
                        ( D.field "displayName" (D.maybe D.string) )
                    )
                )
            )
        DidLogin profile ->
            ( { model | currentUser = Just profile }
            , F.listenOn fbApp "chats" "child_added"
                ( F.expectEmpty DidListenMessages )
                ( F.expect GotMessage D.string )
            )
        SendMessage newMessage ->
            ( model
            , F.call2 fbApp "fbPushValue"
                ( E.string "chats" )
                ( E.string newMessage )
                ( F.expectEmpty DidSendMessage )
            )
        DidSendMessage ->
            ( { model | newMessage = "" }, Cmd.none )
        GotMessage inboundMessage ->
            ( { model | chatMessages = inboundMessage :: model.chatMessages }
            , Cmd.none
            )
        FB fbMsg -> -- Forward msg to Firebase module
            let
                ( updatedModel, fbCmd ) = F.firebaseUpdate fbApp fbMsg model.fbModel
            in
            ( { model | fbModel = updatedModel }, fbCmd )
        _ ->
            ( model, Cmd.none )
