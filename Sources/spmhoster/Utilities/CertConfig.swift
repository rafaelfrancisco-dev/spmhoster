import Vapor

struct CertConfig {
  let certPath: String
}

struct CertConfigKey: StorageKey {
  typealias Value = CertConfig
}
