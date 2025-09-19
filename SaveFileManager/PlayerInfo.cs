using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection.PortableExecutable;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace SaveFileManager
{

    public class ProfileManager
    {
        public static int gUserVersion = 12;

        public static string basePath = "C:\\Users\\RobertG\\source\\repos\\PvZ-Quality-of-the-Lawn-Decompile\\Debug\\savefiles\\userdata\\";

        public List<PlayerInfo> SaveFiles = new List<PlayerInfo>();

        public ProfileManager()
        {
            ReadProfiles();
        }

        private void ReadProfiles()
        {
            using (var reader = new BinaryReader(File.OpenRead(basePath + "users.dat")))
            {
                uint version = reader.ReadUInt32();
                if (version != 14)
                {
                    throw new Exception("Unkonwn version number " + version);
                }
                ushort profileCount = reader.ReadUInt16();
                for (int idx = 0; idx < profileCount; idx++)
                {
                    PlayerInfo info = LoadSummary(reader);
                    SaveFiles.Add(info);
                }
            }
        }

        private PlayerInfo LoadSummary(BinaryReader reader)
        {
            var stringLen = reader.ReadUInt16();
            string name = new(reader.ReadChars(stringLen));
            var seq = reader.ReadUInt32();
            var id = reader.ReadUInt32();
            return new PlayerInfo
            {
                Id = id,
                Seq = seq,
                Name = name
            };
        }

        public PlayerDetails Load(uint Id)
        {
            PlayerDetails result = new();
            using (var reader = new BinaryReader(File.OpenRead(basePath + $"user{Id}.dat")))
            {
                uint version = reader.ReadUInt32();

                result.Levels = reader.ReadUInt32();
                result.Coins = reader.ReadUInt32();
                result.FinishedAdventures = reader.ReadUInt32();

                for (int i = 0; i < 100; i++)
                {
                    result.mChallengeRecords.Add((int)reader.ReadUInt32());
                }
                for (int i = 0; i < 80; i++)
                {
                    result.mPurchases.Add((int)reader.ReadUInt32());
                }
                result.mPlayTimeActivePlayer = reader.ReadUInt32();
                result.mPlayTimeInactivePlayer = reader.ReadUInt32();
                result.mHasUsedCheatKeys = reader.ReadUInt32();
                result.mHasWokenStinky = reader.ReadUInt32();
                result.mDidntPurchasePacketUpgrade = reader.ReadUInt32();
                result.mLastStinkyChocolateTime = reader.ReadUInt32();
                result.mStinkyPosX = reader.ReadUInt32();
                result.mStinkyPosY = reader.ReadUInt32();
                result.mHasUnlockedMinigames = reader.ReadUInt32();
                result.mHasUnlockedPuzzleMode = reader.ReadUInt32();
                result.mHasNewMiniGame = reader.ReadUInt32();
                result.mHasNewScaryPotter = reader.ReadUInt32();
                result.mHasNewIZombie = reader.ReadUInt32();
                result.mHasNewSurvival = reader.ReadUInt32();
                result.mHasUnlockedSurvivalMode = reader.ReadUInt32();
                result.mNeedsMessageOnGameSelector = reader.ReadUInt32();
                result.mNeedsMagicTacoReward = reader.ReadUInt32();
                result.mHasSeenStinky = reader.ReadUInt32();
                result.mHasSeenUpsell = reader.ReadUInt32();
                result.mPlaceHolderPlayerStats = reader.ReadUInt32();
                result.mNumPottedPlants = reader.ReadUInt32();

                for (int i = 0; i < result.mNumPottedPlants; i++)
                {
                    result.mPottedPlant.Add(reader.ReadBytes(88));
                    //theSync.SyncBytes(&mPottedPlant[i], sizeof(PottedPlant));
                }
                for (int i = 0; i < 20; i++)
                {
                    result.mEarnedAchievements.Add(reader.ReadBoolean());
                }
                for (int i = 0; i < 20; i++)
                {
                    result.mShownedAchievements.Add(reader.ReadBoolean());
                }


            }
            return result;
        }
    
        public void Save(PlayerDetails details, uint Id)
        {
            using (var writer = new BinaryWriter(File.OpenWrite(basePath + $"user{Id}.dat")))
            {
                writer.Write(gUserVersion);

                writer.Write(details.Levels);
                writer.Write(details.Coins);
                writer.Write(details.FinishedAdventures);

                for (int i = 0; i < 100; i++)
                {
                    writer.Write((uint)details.mChallengeRecords[i]);
                }
                for (int i = 0; i < 80; i++)
                {
                    writer.Write((uint)details.mPurchases[i]);
                }
                writer.Write(details.mPlayTimeActivePlayer);

                writer.Write(details.mPlayTimeActivePlayer);
                writer.Write(details.mPlayTimeInactivePlayer);
                writer.Write(details.mHasUsedCheatKeys);
                writer.Write(details.mHasWokenStinky);
                writer.Write(details.mDidntPurchasePacketUpgrade);
                writer.Write(details.mLastStinkyChocolateTime);
                writer.Write(details.mStinkyPosX);
                writer.Write(details.mStinkyPosY);
                writer.Write(details.mHasUnlockedMinigames);
                writer.Write(details.mHasUnlockedPuzzleMode);
                writer.Write(details.mHasNewMiniGame);
                writer.Write(details.mHasNewScaryPotter);
                writer.Write(details.mHasNewIZombie);
                writer.Write(details.mHasNewSurvival);
                writer.Write(details.mHasUnlockedSurvivalMode);
                writer.Write(details.mNeedsMessageOnGameSelector);
                writer.Write(details.mNeedsMagicTacoReward);
                writer.Write(details.mHasSeenStinky);
                writer.Write(details.mHasSeenUpsell);
                writer.Write(details.mPlaceHolderPlayerStats);
                writer.Write(details.mNumPottedPlants);

                for (int i = 0; i < details.mNumPottedPlants; i++)
                {
                    writer.Write(details.mPottedPlant[i]);
                    //theSync.SyncBytes(&mPottedPlant[i], sizeof(PottedPlant));
                }
                for (int i = 0; i < 20; i++)
                {
                    writer.Write(details.mEarnedAchievements[i]);
                }
                for (int i = 0; i < 20; i++)
                {
                    writer.Write(details.mShownedAchievements[i]);
                }

            }
        }
    
    }


    public class PlayerInfo
    {
            public uint Seq { get; set; }
            public uint Id { get; set; }

            public string Name { get; set; }

        public override string ToString()
        {
            return Name;
        }
    }

    public class PlayerDetails
    {
        public uint FinishedAdventures { get; internal set; }
        public uint Coins { get; internal set; }
        public uint Levels { get; internal set; }

        public List<int> mChallengeRecords { get; set; } = new List<int>();
        public List<int> mPurchases { get; set; } = new List<int>();
        public uint mPlayTimeActivePlayer { get; internal set; }
        public uint mPlayTimeInactivePlayer { get; internal set; }
        public uint mHasUsedCheatKeys { get; internal set; }
        public uint mHasWokenStinky { get; internal set; }
        public uint mDidntPurchasePacketUpgrade { get; internal set; }
        public uint mLastStinkyChocolateTime { get; internal set; }
        public uint mStinkyPosX { get; internal set; }
        public uint mStinkyPosY { get; internal set; }
        public uint mHasUnlockedPuzzleMode { get; internal set; }
        public uint mHasUnlockedMinigames { get; internal set; }
        public uint mHasNewScaryPotter { get; internal set; }
        public uint mHasNewMiniGame { get; internal set; }
        public uint mHasNewIZombie { get; internal set; }
        public uint mHasNewSurvival { get; internal set; }
        public uint mHasUnlockedSurvivalMode { get; internal set; }
        public uint mNeedsMessageOnGameSelector { get; internal set; }
        public uint mNeedsMagicTacoReward { get; internal set; }
        public uint mHasSeenStinky { get; internal set; }
        public uint mHasSeenUpsell { get; internal set; }
        public uint mPlaceHolderPlayerStats { get; internal set; }
        public uint mNumPottedPlants { get; internal set; }

        public List<bool> mEarnedAchievements { get; set; } = new List<bool>();
        public List<bool> mShownedAchievements { get; set; } = new List<bool>();

        public List<byte[]> mPottedPlant { get; set; } = new List<byte[]>();
    }

}

