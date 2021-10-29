import './app.scss';
import { Elm } from './Main.elm';

import FBinit from './lib';

const app = Elm.Main.init({
    node: document.querySelector('#app'),
});

(FBinit(app.ports)()).then((exit) => console.log());

