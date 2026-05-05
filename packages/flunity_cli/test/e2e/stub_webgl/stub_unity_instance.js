// Mimics what Unity's WebGL build does: defines a stub unityInstance and calls
// window.flunity.ready(instance). Only used in the smoke test.
window.addEventListener('load', function () {
  var stubInstance = {
    SendMessage: function (gameObject, method, value) {
      console.log('[stub Unity] SendMessage', gameObject, method, value);
    }
  };
  window.flunity.ready(stubInstance);
});
