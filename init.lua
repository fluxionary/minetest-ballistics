futil.check_version({ year = 2024, month = 2, day = 3 }, "safecast")

ballistics = fmod.create()

ballistics.dofile("util")
ballistics.dofile("api", "init")
ballistics.dofile("test_tools", "init")
