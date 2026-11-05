import XCTest
@testable import BeBaduy
final class ActivityTests: XCTestCase {
    @MainActor func testLandPreparationValidationAndReplay() {
        let land = NarawasViewModel(); land.start(); land.choose(-1); land.choose(0); land.choose(2)
        XCTAssertFalse(land.session.showsDescription); XCTAssertFalse(land.session.feedback.isEmpty)
        land.choose(1); XCTAssertTrue(land.session.showsDescription)
        let clearing = NyacarViewModel(); clearing.start(); clearing.clear(4)
        XCTAssertTrue(clearing.cleared.isEmpty)
        clearing.clear(0); clearing.clear(0); XCTAssertEqual(clearing.cleared.count, 1)
        for i in 1..<4 { clearing.clear(i) }; XCTAssertTrue(clearing.session.showsDescription)
        clearing.start(); XCTAssertTrue(clearing.cleared.isEmpty)
        let drying = NgaganggangViewModel(); drying.start(); drying.visit(.nan); drying.visit(2); drying.visit(2)
        XCTAssertFalse(drying.session.showsDescription)
        drying.visit(0); drying.visit(1); XCTAssertTrue(drying.session.showsDescription)
        let order = NgahuruViewModel(); order.start(); order.place(at: 0)
        for i in 0..<3 { order.select(i); order.place(at: 2-i) }
        XCTAssertFalse(order.session.showsDescription)
        XCTAssertFalse(order.session.feedback.isEmpty)
        for i in 0..<3 { order.select(i); order.place(at: i) }
        XCTAssertTrue(order.session.showsDescription)
    }
    @MainActor func testCareValidationAndIsolation() {
        let weeds = NgoredViewModel(); weeds.start(); weeds.remove(4); XCTAssertTrue(weeds.removed.isEmpty)
        weeds.remove(0); weeds.remove(0); XCTAssertEqual(weeds.removed.count, 1)
        let plants = NgubaranPareViewModel(); plants.start(); plants.match(0); plants.select(0); plants.match(2)
        XCTAssertTrue(plants.matched.isEmpty)
        for i in 0..<3 { plants.select(i); plants.match(i); plants.select(i); plants.match(i) }
        XCTAssertTrue(plants.session.showsDescription); XCTAssertEqual(plants.matched.count, 3)
        plants.start(); XCTAssertTrue(plants.matched.isEmpty)
        XCTAssertEqual(weeds.removed, [0])
        for i in 1..<4 { weeds.remove(i) }; XCTAssertTrue(weeds.session.showsDescription)
    }
    @MainActor func testHarvestTransportAndStorage() {
        let harvest = DibuatViewModel(); harvest.start(); harvest.harvest(99)
        harvest.harvest(0); harvest.harvest(0); XCTAssertEqual(harvest.harvested.count, 1)
        for i in 1..<4 { harvest.harvest(i) }; XCTAssertTrue(harvest.session.showsDescription)
        let drying = DryingRiceViewModel(); drying.start(); drying.place(at: 0); XCTAssertTrue(drying.rack.isEmpty)
        drying.select(0); drying.place(at: 0); drying.select(0); drying.place(at: 1)
        XCTAssertEqual(drying.rack.count, 1)
        drying.select(1); drying.place(at: 0); XCTAssertEqual(drying.rack.count, 1)
        drying.place(at: 1); drying.select(2); drying.place(at: 2); XCTAssertTrue(drying.session.showsDescription)
        let route = NgunjalViewModel(); route.start(); route.visit(2); XCTAssertEqual(route.reached, 0)
        route.visit(0); route.visit(0); XCTAssertEqual(route.reached, 1)
        route.visit(1); route.visit(2); XCTAssertTrue(route.session.showsDescription)
        let storage = NgaleuitkeunPareViewModel(); storage.start(); storage.place(at: 0); storage.select(4)
        XCTAssertTrue(storage.storage.isEmpty)
        storage.select(0); storage.place(at: 0); storage.select(1); storage.place(at: 0)
        XCTAssertEqual(storage.storage.count, 1)
        storage.place(at: 1); storage.select(2); storage.place(at: 2)
        XCTAssertTrue(storage.session.showsDescription)
        XCTAssertTrue(harvest.session.showsDescription)
    }
    @MainActor func testExplicitDemonstrationAndNoPassiveCompletion() {
        var session = PhaseSessionState(); XCTAssertFalse(session.showsDescription)
        session.start(); XCTAssertFalse(session.showsDescription)
        let land = NarawasViewModel(); land.start(); land.demonstrate(); XCTAssertEqual(land.session.outcome, .observed)
        let clearing = NyacarViewModel(); clearing.start(); clearing.demonstrate(); XCTAssertEqual(clearing.session.outcome, .observed)
        let drying = NgaganggangViewModel(); drying.start(); drying.demonstrate(); XCTAssertEqual(drying.session.outcome, .observed)
        let order = NgahuruViewModel(); order.start(); order.demonstrate(); XCTAssertEqual(order.session.outcome, .observed)
        let weeds = NgoredViewModel(); weeds.start(); weeds.demonstrate(); XCTAssertEqual(weeds.session.outcome, .observed)
        let plants = NgubaranPareViewModel(); plants.start(); plants.demonstrate(); XCTAssertEqual(plants.session.outcome, .observed)
        let harvest = DibuatViewModel(); harvest.start(); harvest.demonstrate(); XCTAssertEqual(harvest.session.outcome, .observed)
        let rack = DryingRiceViewModel(); rack.start(); rack.demonstrate(); XCTAssertEqual(rack.session.outcome, .observed)
        let route = NgunjalViewModel(); route.start(); route.demonstrate(); XCTAssertEqual(route.session.outcome, .observed)
        let storage = NgaleuitkeunPareViewModel(); storage.start(); storage.demonstrate(); XCTAssertEqual(storage.session.outcome, .observed)
    }
}
