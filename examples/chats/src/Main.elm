module Main exposing (main)

import Browser exposing (Document)
import Html exposing (Html, div, h1, p, text)
import Firebase as F

main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , subscriptions = subscriptions
        , update = update
        }


type alias Model = 
    { currentUser : Maybe String
    , chatMessages : List String
    }


type Msg 
    = Login String String
    | DidLogin String
    | FB ( F.FirebaseMsg Msg )
    | SendMessage String
    | GotMessages ( List String )


init : () -> ( Model, Cmd Msg )
init () =
    (   { currentUser = Nothing
        , chatMessages = []
        }
    , Cmd.none
    )


view : Model -> Document Msg
view model =
    { title = "Chat App - Demo"
    , body =
        [ h1 [] [ text "Chat App" ]
        , p [] [ text "Initializing..." ]
        ]
    }   


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )