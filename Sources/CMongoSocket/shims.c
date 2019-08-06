#include <shims.h>

void COpenKittenSSL_init() {
    #if OPENSSL_API_COMPAT < 0x10100000L
    SSL_library_init();
    SSL_load_error_strings();
    OPENSSL_config(NULL);
    OPENSSL_add_all_algorithms_conf();
    #else
    OPENSSL_init_ssl();
    #endif
}

const SSL_METHOD *COpenKittenSSL_client_method() {
    #if OPENSSL_API_COMPAT < 0x10100000L
    return TLS_client_method();
    #else
    return SSLv23_client_method();
    #endif
}
