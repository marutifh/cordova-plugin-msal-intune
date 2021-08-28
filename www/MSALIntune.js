var exec = require('cordova/exec');


// module.exports = {
//     coolMethod = function (arg0, success, error) {
//         exec(success, error, 'MSALIntune', 'coolMethod', [arg0]);
//     }
// };

exports.coolMethod = function (arg0, success, error) {
    exec(success, error, 'MSALIntune', 'coolMethod', [arg0]);
}

exports.initMSALIntune = function (arg0, success, error) {
    exec(success, error, 'MSALIntune', "initMSALIntune", [arg0]);
}

exports.signOut = function (arg0, success, error) {
    exec(success, error, 'MSALIntune', "signOut", []);
}

exports.signInInteractive = function (arg0, success, error) {
    exec(success, error, 'MSALIntune', "signInInteractive", []);
}

exports.signIn = function (arg0, success, error) {
    exec(success, error, 'MSALIntune', "signIn", []);
}

exports.silentSignIn = function (arg0, success, error) {
    exec(success, error, 'MSALIntune', "silentSignIn", []);
}
