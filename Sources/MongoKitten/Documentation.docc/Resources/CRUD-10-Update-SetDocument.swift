try await users.updateMany(
    where: "role" == "trial",
    setting: [
        "active": false
    ]
)
