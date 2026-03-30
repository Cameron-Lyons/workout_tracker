import Foundation

enum CatalogSeed {
    static let benchPress = UUID(uuidString: "9D4E02E5-FE6A-4A29-9706-52AE57E21400")!
    static let inclineBenchPress = UUID(uuidString: "A23712A8-FA3B-4231-A9CC-F56B4E0A1A02")!
    static let dumbbellFly = UUID(uuidString: "C33BE145-B321-4C14-B6B8-BB384E2B0280")!
    static let backSquat = UUID(uuidString: "4B572B89-5A24-43E0-9A8C-4FD96EC60F85")!
    static let frontSquat = UUID(uuidString: "E9B7A3B0-65E0-4D4D-A7C3-03C5E4F45E56")!
    static let deadlift = UUID(uuidString: "7A8C8F4E-97D3-4384-8C5B-2FC4B0F79F76")!
    static let romanianDeadlift = UUID(uuidString: "4BB1B3B3-9036-45B4-A94F-0F74A9E613E1")!
    static let overheadPress = UUID(uuidString: "6B2AB7AA-C4C7-4C5A-AB11-08D0773F2C4A")!
    static let dumbbellShoulderPress = UUID(uuidString: "6302DDF0-66D2-487E-A065-C19BAF820A85")!
    static let powerClean = UUID(uuidString: "9C880197-BDF5-44F0-B0C4-B4C7067B5584")!
    static let barbellRow = UUID(uuidString: "581C76C0-D2F9-4983-90A1-0B75A7940C93")!
    static let pullUp = UUID(uuidString: "8446357E-46D5-4ACE-96FD-73CBA1B988F2")!
    static let weightedPullUp = UUID(uuidString: "3D09C996-3D5E-4B39-9D82-F4CDB76196C5")!
    static let latPulldown = UUID(uuidString: "51852E98-96A5-4B28-BE98-7259C821AB3E")!
    static let seatedCableRow = UUID(uuidString: "1BCB11A6-D81D-41A0-81CF-9A9E016F417D")!
    static let dips = UUID(uuidString: "BC345C05-A84A-46AC-BB10-A47C8520E08B")!
    static let lateralRaise = UUID(uuidString: "A7FA92CF-E3A4-4A12-897E-EC63E599A906")!
    static let facePull = UUID(uuidString: "8D6E8B56-ACD7-4687-8AFE-0A7D84B0A189")!
    static let rearDeltFly = UUID(uuidString: "D40CF4D4-362C-4E53-B736-DAA80D567456")!
    static let tricepsPushdown = UUID(uuidString: "03472BC6-B9CB-41AB-80A6-B0C786AB9F5E")!
    static let skullCrusher = UUID(uuidString: "980F575D-F91D-4CF9-B225-F3540C07A5C5")!
    static let barbellCurl = UUID(uuidString: "A8001A73-530A-4F70-9CD4-B82F520E278E")!
    static let hammerCurl = UUID(uuidString: "9FD7BC0E-BEAF-4893-8AFB-975652F357A4")!
    static let legPress = UUID(uuidString: "61021D3E-3AA9-4393-B734-81D96DE2D645")!
    static let legCurl = UUID(uuidString: "BF1C7685-D25F-45E6-9C3F-E31B9E44E83A")!
    static let legExtension = UUID(uuidString: "8BFF0227-117A-4E28-A5F2-09EC28EAB23E")!
    static let walkingLunge = UUID(uuidString: "A6D885B0-A734-4CD6-9676-E8379F50B74C")!
    static let bulgarianSplitSquat = UUID(uuidString: "E4BF4790-144A-4D13-B782-017E732B47DB")!
    static let hipThrust = UUID(uuidString: "0AA75AAB-BE44-4B58-96D6-E2507066E8BF")!
    static let standingCalfRaise = UUID(uuidString: "E3F726AF-A4A9-4A72-B26A-C48E2174B94F")!
    static let seatedCalfRaise = UUID(uuidString: "5F388D61-742B-4AB2-B1FB-C0E96D08B236")!

    static func defaultCatalog() -> [ExerciseCatalogItem] {
        [
            ExerciseCatalogItem(id: benchPress, name: "Bench Press", category: .chest),
            ExerciseCatalogItem(id: inclineBenchPress, name: "Incline Bench Press", category: .chest),
            ExerciseCatalogItem(id: dumbbellFly, name: "Dumbbell Fly", category: .chest),
            ExerciseCatalogItem(id: backSquat, name: "Back Squat", category: .legs),
            ExerciseCatalogItem(id: frontSquat, name: "Front Squat", category: .legs),
            ExerciseCatalogItem(id: deadlift, name: "Deadlift", category: .legs),
            ExerciseCatalogItem(id: romanianDeadlift, name: "Romanian Deadlift", category: .legs),
            ExerciseCatalogItem(id: overheadPress, name: "Overhead Press", category: .shoulders),
            ExerciseCatalogItem(id: dumbbellShoulderPress, name: "Dumbbell Shoulder Press", category: .shoulders),
            ExerciseCatalogItem(id: powerClean, name: "Power Clean", category: .fullBody),
            ExerciseCatalogItem(id: barbellRow, name: "Barbell Row", category: .back),
            ExerciseCatalogItem(id: pullUp, name: "Pull Up", category: .back),
            ExerciseCatalogItem(id: weightedPullUp, name: "Weighted Pull Up", aliases: ["Pull Up"], category: .back),
            ExerciseCatalogItem(id: latPulldown, name: "Lat Pulldown", category: .back),
            ExerciseCatalogItem(id: seatedCableRow, name: "Seated Cable Row", category: .back),
            ExerciseCatalogItem(id: dips, name: "Dips", category: .chest),
            ExerciseCatalogItem(id: lateralRaise, name: "Lateral Raise", category: .shoulders),
            ExerciseCatalogItem(id: facePull, name: "Face Pull", category: .shoulders),
            ExerciseCatalogItem(id: rearDeltFly, name: "Rear Delt Fly", category: .shoulders),
            ExerciseCatalogItem(id: tricepsPushdown, name: "Triceps Pushdown", category: .arms),
            ExerciseCatalogItem(id: skullCrusher, name: "Skull Crusher", category: .arms),
            ExerciseCatalogItem(id: barbellCurl, name: "Barbell Curl", category: .arms),
            ExerciseCatalogItem(id: hammerCurl, name: "Hammer Curl", category: .arms),
            ExerciseCatalogItem(id: legPress, name: "Leg Press", category: .legs),
            ExerciseCatalogItem(id: legCurl, name: "Leg Curl", category: .legs),
            ExerciseCatalogItem(id: legExtension, name: "Leg Extension", category: .legs),
            ExerciseCatalogItem(id: walkingLunge, name: "Walking Lunge", category: .legs),
            ExerciseCatalogItem(id: bulgarianSplitSquat, name: "Bulgarian Split Squat", category: .legs),
            ExerciseCatalogItem(id: hipThrust, name: "Hip Thrust", category: .legs),
            ExerciseCatalogItem(id: standingCalfRaise, name: "Standing Calf Raise", category: .legs),
            ExerciseCatalogItem(id: seatedCalfRaise, name: "Seated Calf Raise", category: .legs),
        ]
    }
}
