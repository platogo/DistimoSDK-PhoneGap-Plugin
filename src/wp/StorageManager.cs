/**
 *  Copyright (c) 2012 Distimo. All rights reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

using System;
using System.IO;
using System.IO.IsolatedStorage;
using System.Text;

namespace Distimo
{
    internal sealed class StorageManager
    {
        private static readonly String DIRECTORY_NAME = "dTIGyNcuJ5UlH8oFjtmv";
        private static IsolatedStorageFile storage = IsolatedStorageFile.GetUserStoreForApplication();

        internal static void store(String content, String fileName)
        {
            store(content, fileName, false);
        }
        internal static void store(String content, String fileName, Boolean append)
        {
            Utils.log("StoreManager.store(" + fileName + ")");

            Boolean directoryExists = storage.DirectoryExists(DIRECTORY_NAME);
            if (!directoryExists)
            {
                try
                {
                    storage.CreateDirectory(DIRECTORY_NAME);
                    directoryExists = storage.DirectoryExists(DIRECTORY_NAME);
                }
                catch (Exception e)
                {
                    Utils.log(e.StackTrace);
                }
            }

            if (directoryExists)
            {
                String file = DIRECTORY_NAME + "/" + fileName;
                FileMode mode = (append ? FileMode.Append : FileMode.Create);
                FileAccess access = FileAccess.Write;

                try
                {
                    using (FileStream fs = new IsolatedStorageFileStream(file, mode, access, storage))
                    {
                        using (StreamWriter sw = new StreamWriter(fs))
                        {
                            sw.Write(content);
                        }

                        fs.Close();
                    }
                }
                catch (Exception e)
                {
                    Utils.log(e.StackTrace);
                }
            }
        }

        internal static String read(String fileName)
        {
            return read(fileName, false);
        }
        internal static String read(String fileName, Boolean deleteFile)
        {
            Utils.log("StoreManager.read(" + fileName + ")");

            String result = null;

            Boolean directoryExists = storage.DirectoryExists(DIRECTORY_NAME);
            if (directoryExists)
            {
                String file = DIRECTORY_NAME + "/" + fileName;
                if (storage.FileExists(file))
                {
                    FileMode mode = FileMode.Open;
                    FileAccess access = FileAccess.Read;

                    try
                    {
                        using (FileStream fs = new IsolatedStorageFileStream(file, mode, access, storage))
                        {
                            using (StreamReader sr = new StreamReader(fs))
                            {
                                result = sr.ReadToEnd();
                            }
                        }

                        if (deleteFile)
                        {
                            storage.DeleteFile(file);
                        }
                    }
                    catch (Exception e)
                    {
                        Utils.log(e.StackTrace);
                    }
                }
            }

            return result;
        }
    }
}
