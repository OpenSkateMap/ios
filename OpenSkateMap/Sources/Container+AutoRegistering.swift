import AccountKit
import AnalyticsKit
import APIClientKit
import AppLinkKit
import CollectionDetailKit
import CollectionsKit
import ContributeKit
import ContributionsKit
public import FactoryKit
import Foundation
import ImageKit
import NotificationsKit
import PeopleKit
import ProfileKit
import ReviewKit
import SpotDetailKit
import SpotModelKit
import SpotsKit
import SpotsMapKit
import SQLiteKit
import UIKit

extension Container: @retroactive AutoRegistering {
    public nonisolated func autoRegister() {
        // FactoryKit calls this inside the first resolution, which is launch, on the main thread.
        MainActor.assumeIsolated {
            userProfileScreen.register { ProfileScreens.publicProfile(userID: $0) }
            spotReportScreen.register { ProfileScreens.reportSpot(id: $0) }
            addVideoScreen.register { AddVideoSheet.make(spotID: $0.spotID, spotTitle: $0.spotTitle) }
            suggestEditScreen.register { NewSpotSheetController(editing: $0) }
            addSpotScreen.register { NewSpotSheetController() }
            collectionPickerScreen.register { CollectionScreens.picker(spotID: $0) }
            collectionsListScreen.register { CollectionScreens.list() }
            userCollectionsScreen.register { CollectionScreens.publicCollections(of: $0) }
            appLinkOpener.register { AppLinkOpener { Container.shared.appLinks().open($0) } }
            discoverCollectionsScreen.register { CollectionScreens.listSheet() }
            discoverCollectionScreen.register { CollectionScreens.collection(id: $0) }
            newCollectionScreen.register { CollectionScreens.newCollection() }
            publishedSpotHandler.register {
                PublishedSpotHandler { visibility in
                    switch visibility {
                    case .public: await Container.shared.spotsSession().syncNow()
                    case .private: await Container.shared.collectionsSession().syncNow()
                    }
                }
            }
            backgroundTime.register { .application }
            blocksChangedHandler.register {
                BlocksChangedHandler { await Container.shared.spotsSession().refreshDetails() }
            }
            databaseSchemas.register { [.spots, .contributions, .people, .review] }
            sessionCredentials.register {
                SessionCredentials(
                    token: { await MainActor.run { Container.shared.authSession().sessionToken } },
                    refused: { token in await MainActor.run { Container.shared.authSession().sessionRefused(token: token) } },
                    doNotTrack: { !Container.shared.analyticsManager().isEnabled() },
                    accountID: {
                        guard case .signedIn(let account) = Container.shared.authSession().phase else {
                            return nil
                        }
                        return account.id
                    },
                )
            }
            accountEndHandler.register {
                AccountEndHandler {
                    Container.shared.notificationsManager().signOut()
                    Container.shared.analyticsManager().reset()
                    // API answers and images (private spots', collections') are per account; the next one on this
                    // device must never be served them.
                    URLCache.shared.removeAllCachedResponses()
                    Container.shared.imageCaches().removeAll()
                    Task {
                        await Container.shared.syncEngine().reset()
                        await Container.shared.contributionsOutbox().reset()
                        await Container.shared.collectionsSync().reset()
                        await Container.shared.peopleStore().reset()
                        await Container.shared.reviewQueueStore().clear()
                    }
                }
            }
            #if DEBUG
            registerPreviewAuth()
            registerLocalAPI()
            #endif
        }
    }

    #if DEBUG
    @MainActor
    private func registerPreviewAuth() {
        for argument in [LaunchArgument.previewAuth, LaunchArgument.previewSignedIn] {
            appleSignInManager.onArg(argument) { .preview }
            authAPIManager.onArg(argument) { .preview }
        }
        keychainManager.onArg(LaunchArgument.previewAuth) { .inMemory() }
        keychainManager.onArg(LaunchArgument.previewSignedIn) { .preview(signedInAs: .preview) }
    }

    @MainActor
    private func registerLocalAPI() {
        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: LaunchArgument.apiBaseURL), let url = URL(string: value) {
            apiServerURL.register { url }
        }
        if let value = defaults.string(forKey: LaunchArgument.imagesBaseURL), let url = URL(string: value) {
            photoURLBuilder.register { PhotoURLBuilder(baseURL: url) }
        }
        if let token = defaults.string(forKey: LaunchArgument.debugToken) {
            keychainManager.register { .signedIn(token: token) }
        }
    }
    #endif
}
