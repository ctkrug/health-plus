import XCTest
import MuscleMap
@testable import HealthAggregator

/// `MuscleTaxonomy` normalizes ExerciseLibrary's free-text muscle labels onto `MuscleMap.Muscle`.
/// These tests pin the mapping table and the subgroup-rollup rule so future edits can't silently
/// drop or misroute a label (which would silently zero out a muscle's tracked volume).
final class MuscleTaxonomyTests: XCTestCase {

    func testCanonicalizeKnownLabels() {
        XCTAssertEqual(MuscleTaxonomy.canonicalize("Chest"), .chest)
        XCTAssertEqual(MuscleTaxonomy.canonicalize("chest"), .chest, "Should be case-insensitive")
        XCTAssertEqual(MuscleTaxonomy.canonicalize("Front Delts"), .frontDeltoid)
        XCTAssertEqual(MuscleTaxonomy.canonicalize("Side Delts"), .deltoids, "No lateral-delt case — falls back to the parent")
        XCTAssertEqual(MuscleTaxonomy.canonicalize("Lats"), .upperBack, "No dedicated lats case in the package")
        XCTAssertEqual(MuscleTaxonomy.canonicalize("Mid Back"), .upperBack)
        XCTAssertEqual(MuscleTaxonomy.canonicalize("Hamstrings"), .hamstring)
        XCTAssertEqual(MuscleTaxonomy.canonicalize("Glutes"), .gluteal)
        XCTAssertEqual(MuscleTaxonomy.canonicalize("Brachialis"), .biceps)
        XCTAssertEqual(MuscleTaxonomy.canonicalize("Soleus"), .calves)
    }

    func testCanonicalizeUnknownLabelReturnsNil() {
        XCTAssertNil(MuscleTaxonomy.canonicalize("Not A Real Muscle"))
    }

    func testBalanceGroupCollapsesNonVisibleSubgroups() {
        XCTAssertEqual(Muscle.upperChest.balanceGroup, .chest)
        XCTAssertEqual(Muscle.lowerChest.balanceGroup, .chest)
        XCTAssertEqual(Muscle.frontDeltoid.balanceGroup, .deltoids)
        XCTAssertEqual(Muscle.rearDeltoid.balanceGroup, .deltoids)
        XCTAssertEqual(Muscle.hipFlexors.balanceGroup, .quadriceps)
    }

    func testBalanceGroupKeepsAlwaysVisibleSubgroupsDistinct() {
        XCTAssertEqual(Muscle.adductors.balanceGroup, .adductors, "adductors renders independently by default")
    }

    func testBalanceGroupIsIdentityForTopLevelMuscles() {
        XCTAssertEqual(Muscle.chest.balanceGroup, .chest)
        XCTAssertEqual(Muscle.hamstring.balanceGroup, .hamstring)
    }

    func testExerciseDefinitionPrimaryAndSecondaryMuscles() {
        guard let benchPress = ExerciseLibrary.find("Bench Press") else {
            return XCTFail("Bench Press should exist in the library")
        }
        XCTAssertEqual(benchPress.primaryCanonicalMuscle, .chest)
        XCTAssertEqual(Set(benchPress.secondaryCanonicalMuscles), [.triceps, .frontDeltoid])
    }

    func testSecondaryMusclesEmptyForSingleMuscleExercise() {
        guard let curl = ExerciseLibrary.find("Barbell Curl") else {
            return XCTFail("Barbell Curl should exist in the library")
        }
        XCTAssertEqual(curl.primaryCanonicalMuscle, .biceps)
        XCTAssertTrue(curl.secondaryCanonicalMuscles.isEmpty)
    }
}
