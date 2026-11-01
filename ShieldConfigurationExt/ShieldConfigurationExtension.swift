import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private var pause: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            title: ShieldConfiguration.Label(text: "Ich zähl bis drei", color: .label),
            subtitle: ShieldConfiguration.Label(text: "Spielzeit ist vorbei", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .white),
            primaryButtonBackgroundColor: .systemBlue
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        pause
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        pause
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        pause
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        pause
    }
}
