futil.check_version({ year = 2024, month = 1, day = 15 }, "need make_registration")

ballistics = fmod.create()

ballistics.dofile("util")
ballistics.dofile("api", "init")
ballistics.dofile("test_tools", "init")
