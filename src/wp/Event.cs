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
using System.Net;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Ink;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using ProtoBuf;
using System.Collections.Generic;

namespace Distimo
{
    [ProtoContract]
    internal class Event
    {
        private static Int32 maxID = 0;

        [ProtoMember(1)]
        public String name { get; set; }
        [ProtoMember(2)]
        public String postData { get; set; }
        [ProtoMember(3)]
        public Dictionary<String, String> parameters { get; set; }
        [ProtoMember(4)]
        public Boolean generateHash { get; set; }
        [ProtoMember(5)]
        public Boolean requiresCookie { get; set; }
        [ProtoMember(6)]
        public long timestamp { get; set; }
        [ProtoMember(7)]
        public String bundleID { get; set; }
        [ProtoMember(8)]
        public String appVersion { get; set; }
        [ProtoMember(9)]
        public String sdkVersion { get; set; }

        public Int32 _id { get; set; }
        public String checksum { get; set; }

        // Constructors

        public Event()
        {

        }

        internal Event(String name, Dictionary<String, String> parameters, String postData, Boolean generateHash, Boolean requiresCookie, long timestamp, String bundleID, String appVersion, String sdkVersion, String publicKey, String privateKey, String uuid, String huid)
        {
            this.name = name;
            this.parameters = parameters;
            this.postData = postData;
            this.generateHash = generateHash;
            this.requiresCookie = requiresCookie;
            this.timestamp = timestamp;
            this.bundleID = bundleID;
            this.appVersion = appVersion;
            this.sdkVersion = sdkVersion;

            this.calculateChecksum(publicKey, privateKey, uuid, huid);

            //Set new ID
            this._id = maxID++;

            Utils.log("Created " + this.name + " event with ID " + this._id);
        }

        // Internal methods

        internal void setNewID()
        {
            this._id = maxID++;
        }

        internal String urlParamString(String publicKey, String uuid, String huid)
        {
            String result = this.urlParamPayload(publicKey, uuid, huid);
            result += "&ct=" + Utils.currentTimeMillis();
            result += "&cs=" + this.checksum;

            return result;
        }

        internal void calculateChecksum(String publicKey, String privateKey, String uuid, String huid)
        {
            String getString = this.urlParamPayload(publicKey, uuid, huid);
            String getPayload = MD5Core.GetHashString(getString);
            Utils.log("Hashing " + getString + " --> " + getPayload);

            String payload = null;

            if (this.postData != null)
            {
                String postPayload = MD5Core.GetHashString(this.postData);
                Utils.log("Hashing " + this.postData + " --> " + postPayload);

                payload = MD5Core.GetHashString(getPayload + postPayload);
                Utils.log("Hashing " + getPayload + postPayload + " --> " + payload);
            }
            else
            {
                payload = getPayload;
            }

            String result = MD5Core.GetHashString(payload + privateKey);
            Utils.log("Hashing " + payload + privateKey + " --> " + result);

            this.checksum = result;
        }

        /*internal String jsonData()
        {
            Dictionary<String, Object> dict = new Dictionary<String, Object>();

            dict["id"] = this._id;
            dict["name"] = this.name;
            dict["parameters"] = this.parameters;
            dict["postData"] = this.postData;
            dict["generateHash"] = this.generateHash;
            dict["requiresCookie"] = this.requiresCookie;
            dict["timestamp"] = this.timestamp;
            dict["bundleID"] = this.bundleID;
            dict["appVersion"] = this.appVersion;
            dict["sdkVersion"] = this.sdkVersion;

            return JsonConvert.SerializeObject(dict);
        }*/

        // Overrides

        public override bool Equals(object obj)
        {
            return (obj.GetType() == typeof(Event) && ((Event)obj)._id == this._id);
        }

        public override int GetHashCode()
        {
            return this._id;
        }

        // Private methods

        private String urlParamPayload(String publicKey, String uuid, String huid)
        {
            String result = "en=" + this.name;

            if (this.requiresCookie)
            {
                result += "&sc=1";
            }
            if (this.generateHash)
            {
                result += "&gh=1";
            }
            result += "&lt=" + this.timestamp;
            result += "&av=" + this.appVersion;
            result += "&sv=" + this.sdkVersion;
            result += "&bu=" + this.bundleID;
            result += "&oi=" + publicKey;
            result += "&uu=" + uuid;
            result += "&hu=" + huid;
            result += "&es=" + "w";

            if (this.parameters != null)
            {
                result += "&ep=" + Uri.EscapeUriString(this.parameterString());
            }

            return result;
        }

        private String parameterString()
        {
            String result = "";

            if (this.parameters != null)
            {
                foreach (var entry in this.parameters)
                {
                    if (result.Length > 0)
                    {
                        result += ";";
                    }
                    result += Uri.EscapeUriString(entry.Key) + "=" + Uri.EscapeUriString(entry.Value);
                }
            }

            return result;
        }
    }
}
