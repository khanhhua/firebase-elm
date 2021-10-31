# Firebase Elm

Since Elm 0.19.1 onwards, the support for custom effect has been dropped in favor of `port`. I have taken this drastic
architectural interruption as an opportunity to deep dive into Elm. The result is this `firebase-elm` library, whose
implementation treats consuming application as the host, and the library itself as an extension. Therefore, in using
this library as is or applying the core concepts, Elm application developers should not fear top-down cascading changes
as in the case of extending a base webapp (template). Think Angular vs React (ie. Angular is an opinionated framework, 
React is simply a view library).

Let's go...

## Application Modeling

First and foremost, don't forget to declare your Main module as a `port module`

Second, import :D this library
```elm
import Firebase as F
```

Then declare the required ports

```elm
port firebaseInput : (Value -> msg) -> Sub msg
port firebaseOutput : Value -> Cmd msg
```

Then, your application `Model`
```elm
type alias Model =
{ ...
, fbModel : F.Model Msg
...
}
```

Then application `Msg`

```Elm
type Msg
    = FirebaseInitialized       -- anything you like here, just an example
    | FB ( F.FirebaseMsg Msg )  -- map this library's Msg within your application's
    | ...
```

Now you can create an instance of Firebase library app, which is a combination of necessary meta-data and Firebase 
specific configuration.

```elm
fbApp : FirebaseApp Msg
fbApp = F.firebaseApp firebaseInput firebaseOutput FB
    |> F.config [ ( "apiKey", "AIzaSyBB6mJ8zC4HeqpnznHVnrqvu7vq3i05HQU" )
                , ( "authDomain", "tictactoe-7d2d5.firebaseapp.com" )
                , ( "projectId", "tictactoe-7d2d5" )
                , ( "storageBucket", "tictactoe-7d2d5.appspot.com")
                , ( "messagingSenderId", "1060266018339" )
                , ( "appId", "1:1060266018339:web:c3a29cb4f0361ab8435396" )
                , ( "databaseURL", "https://tictactoe-7d2d5-default-rtdb.europe-west1.firebasedatabase.app/" )
                ]
```
`FB` Msg constructor is technically a `to application msg` mapper.

We are then ready to initialize the underlying Firebase connection when Elm application fires up.

```elm
init () =
    (   { ...
        , fbModel = F.init fbApp
        , ...
        }
    , F.initialize fbApp (F.expectEmpty FirebaseInitialized)
    )
```

In order to handle inbound messages from Firebase, we need to subscribe as follows 
```elm
subscriptions model =
     F.subscriptions fbApp model.fbModel
```

Last but not least, we need to forward Firebase specific `Msg` to the library inner clockworks.

```elm
update msg model =
    case msg of
        FirebaseInitialized -> -- 
            ...
        FB fbMsg ->
            let
                ( updatedModel, fbCmd ) = F.firebaseUpdate fbApp fbMsg model.fbModel
            in
            ( { model | fbModel = updatedModel }, fbCmd )
```
Of course, your application could intercept and handle `msg` before forwarding. It is all up to you, dear developer!

That is it! We have successfully mapped this library's elements (Msg and Model) to your own application's counterparts.
Think Category Theory! All the above could be summarized as declaring the morphisms between your application and the
library itself. This library totally does not care about how you design your application, how you model your data, how
your view looks like! Wonderful Separation of Concerns principle, right?

## Examples

### Chats

- [Live Preview](https://firebase-elm-chats.khanhhua.com/) here
- [Source code](https://github.com/khanhhua/firebase-elm/tree/master/examples/chats) 
