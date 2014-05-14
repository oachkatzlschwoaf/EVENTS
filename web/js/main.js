var base_url = window.location.protocol + '//' + window.location.hostname + '/';

function doLogin() {
    VK.Auth.login(
        null,
        VK.access.FRIENDS | VK.access.AUDIO
    );
}
