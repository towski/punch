/***** BEGIN LICENSE BLOCK *****
 * Version: CPL 1.0/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Common Public
 * License Version 1.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.eclipse.org/legal/cpl-v10.html
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * Copyright (C) 2013 The JRuby Team (team@jruby.org)
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either of the GNU General Public License Version 2 or later (the "GPL"),
 * or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the CPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the CPL, the GPL or the LGPL.
 ***** END LICENSE BLOCK *****/
package org.jruby.ext.dbm;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.channels.FileChannel;
import java.util.Map.Entry;
import java.util.concurrent.ConcurrentNavigableMap;
import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyEnumerator;
import org.jruby.RubyFile;
import org.jruby.RubyHash;
import org.jruby.RubyNumeric;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.io.ModeFlags;
import org.mapdb.DB;
import org.mapdb.DBMaker;

/**
 *
 */
public class RubyDBM extends RubyObject {
    private static final int NIL_INSTEAD_OF_ERROR = -1;
    private static final int DEFAULT_MODE = 0666;
    private static final int RUBY_DBM_RW_BIT = 0x20000000;
    private static final int READER = ModeFlags.RDONLY | RUBY_DBM_RW_BIT;
    private static final int WRITER = ModeFlags.RDWR | RUBY_DBM_RW_BIT;
    private static final int WRCREAT = ModeFlags.RDWR | ModeFlags.CREAT | RUBY_DBM_RW_BIT;
    private static final int NEWDB = ModeFlags.RDWR | ModeFlags.CREAT | ModeFlags.TRUNC | RUBY_DBM_RW_BIT;
    private static final RuntimeException NIL_HACK_EXCEPTION = new RuntimeException();
    
    private DB db = null;
    private ConcurrentNavigableMap<String, String> map = null;
    
    public static void initDBM(Ruby runtime) {
        RubyClass dbm = runtime.defineClass("DBM", runtime.getObject(), new ObjectAllocator() {
            @Override
            public IRubyObject allocate(Ruby runtime, RubyClass klazz) {
                return new RubyDBM(runtime, klazz);
            }
        });

        dbm.includeModule(runtime.getEnumerable());
        
        runtime.defineClass("DBMError", runtime.getStandardError(),runtime.getStandardError().getAllocator());

        dbm.defineConstant("READER", runtime.newFixnum(READER));
        dbm.defineConstant("WRITER", runtime.newFixnum(WRITER));
        dbm.defineConstant("WRCREAT", runtime.newFixnum(WRCREAT));
        dbm.defineConstant("NEWDB", runtime.newFixnum(NEWDB));
        // FIXME: This should be single-sourced as part of pom.xml
        dbm.defineConstant("VERSION", runtime.newString("MapDB 0.9.7"));

        dbm.defineAnnotatedMethods(RubyDBM.class);
    }
    
    public RubyDBM(Ruby runtime, RubyClass klazz) {
        super(runtime, klazz);
    }
    
    // The need for 'nil' mode to return nil from new/open on error requires defining an explicit new method
    @JRubyMethod(meta = true, name = "new", required = 1, optional = 2)
    public static IRubyObject _new(ThreadContext context, IRubyObject recv, IRubyObject[] args) {
        switch (args.length) {
            case 1: return open(context, recv, args[0], Block.NULL_BLOCK);
            case 2: return open(context, recv, args[0], args[1], Block.NULL_BLOCK);
        }
        return open(context, recv, args[0], args[1], args[2], Block.NULL_BLOCK); // 3 args
    }
    
    @JRubyMethod(meta = true)
    public static IRubyObject open(ThreadContext context, IRubyObject recv, IRubyObject filename, Block block) {
        return open(context, recv, filename, context.runtime.newFixnum(DEFAULT_MODE), block);
    }
    
    @JRubyMethod(meta = true)
    public static IRubyObject open(ThreadContext context, IRubyObject recv, IRubyObject filename, IRubyObject mode, Block block) {
        return open(context, recv, filename, mode, context.runtime.getNil(), block);
    }
    
    @JRubyMethod(meta = true)
    public static IRubyObject open(ThreadContext context, IRubyObject recv, IRubyObject filename, IRubyObject mode, IRubyObject flags, Block block) {
        RubyDBM dbm;
        
        try {
            dbm = (RubyDBM) ((RubyClass) recv).newInstance(context, filename, mode, flags, block);
        } catch (RuntimeException e) { // by-pass allocator logic which always will return new instance.
            if (e == NIL_HACK_EXCEPTION) return context.runtime.getNil();
            throw e;
        }
        
        if (block.isGiven()) {
            IRubyObject result = block.yieldSpecific(context, dbm);
            
            dbm.close(context);
            
            return result;
        }

        return dbm;
    }
    
    @JRubyMethod
    public IRubyObject initialize(ThreadContext context, IRubyObject filename) {
        return initialize(context, filename, context.runtime.newFixnum(DEFAULT_MODE));
    }
    
    @JRubyMethod
    public IRubyObject initialize(ThreadContext context, IRubyObject filename, IRubyObject mode) {
        return initialize(context, filename, mode, context.runtime.getNil());
    }
    
    @JRubyMethod
    public IRubyObject initialize(ThreadContext context, IRubyObject filename, IRubyObject modeArg, IRubyObject flagsArg) {
        int mode = modeArg.isNil() ? NIL_INSTEAD_OF_ERROR : RubyNumeric.num2int(modeArg);
        int openFlags = flagsArg.isNil() ? 0 : RubyNumeric.num2int(flagsArg);
        String file = RubyFile.get_path(context, filename).asJavaString();
        File dbFile = new File(file);
        
        // Only if default flag value or explicit IO::RDONLY passed in we need an early check since RDONLY is 0.
        if (mode == NIL_INSTEAD_OF_ERROR && openFlags == 0 && !dbFile.exists()) throw NIL_HACK_EXCEPTION;
        
        if (openFlags == 0) openFlags = WRCREAT;
        
        // We handle as much as we can before passing to underlying db for flags.
        if ((openFlags & ModeFlags.CREAT) == 0 && !dbFile.exists()) {
            if (mode == NIL_INSTEAD_OF_ERROR) throw NIL_HACK_EXCEPTION;
            
            throw context.runtime.newErrnoENOENTError();
        }
        
        if ((openFlags & ModeFlags.TRUNC) != 0) truncate(dbFile);
        
        DBMaker maker = DBMaker.newFileDB(dbFile).closeOnJvmShutdown();

        // If explicitly request as read-only or file mode is not writable open in read-only mode.
        if (openFlags == READER || (dbFile.exists() && !dbFile.canWrite())) maker = maker.readOnly();
        
        db = maker.make();
        map = db.getTreeMap("");
        
        return this;
    }
    
    @JRubyMethod
    public IRubyObject close(ThreadContext context) {
        ensureDBOpen(context);
        if (!isReadOnly()) db.commit();
        db.close();
        db = null;
        map = null;
        
        return context.runtime.getNil();
    }
    
    @JRubyMethod(name = "closed?")
    public IRubyObject closed_p(ThreadContext context) {
        return context.runtime.newBoolean(db == null);
    }
    
    @JRubyMethod(name = "[]")
    public IRubyObject aref(ThreadContext context, IRubyObject key) {
        ensureDBOpen(context);
        String value = map.get(str(context, key));
        
        return value != null ? context.runtime.newString(value) : context.runtime.getNil();
    }
    
    @JRubyMethod
    public IRubyObject fetch(ThreadContext context, IRubyObject key, Block block) {
        ensureDBOpen(context);
        String value = map.get(str(context, key));
        
        if (value == null) {
            if (block.isGiven()) return block.yield(context, key);
            
            throw context.runtime.newIndexError("key not found");
        }

        return context.runtime.newString(value);
    }
    
    @JRubyMethod
    public IRubyObject fetch(ThreadContext context, IRubyObject key, IRubyObject ifNone, Block block) {
        ensureDBOpen(context);
        String value = map.get(str(context, key));

        return value != null ? context.runtime.newString(value) : ifNone;
    }
    
    @JRubyMethod(name = {"[]=", "store"})
    public IRubyObject aset(ThreadContext context, IRubyObject key, IRubyObject value) {
        ensureDBOpen(context);
        ensureNotFrozen(context);
        
        store(context, key, value);
        db.commit();
        
        return value;
    }
    
    @JRubyMethod
    public IRubyObject index(ThreadContext context, IRubyObject value) {
        context.runtime.getWarnings().warn("DBM#index is deprecated; use DBM#key");

        return key(context, value);
    }
    
    @JRubyMethod
    public IRubyObject key(ThreadContext context, IRubyObject value) {
        ensureDBOpen(context);
        String valueString = str(context, value);
        
        for (String key : map.keySet()) {
            if (valueString.equals(map.get(key))) return context.runtime.newString(key);
        }
        
        return context.runtime.getNil();
    }
    
    @JRubyMethod
    public IRubyObject select(ThreadContext context, Block block) {
        ensureDBOpen(context);
        RubyArray array = context.runtime.newArray();
        
        for (String key : map.keySet()) {
            IRubyObject rkey = rstr(context, key);
            IRubyObject rvalue = rstr(context, map.get(key));
            
            if (block.yieldSpecific(context, rkey, rvalue).isTrue()) array.append(context.runtime.newArray(rkey, rvalue));
        }
        
        return array;
    }   
    
    @JRubyMethod(rest = true)
    public IRubyObject values_at(ThreadContext context, IRubyObject[] keys) {
        ensureDBOpen(context);
        RubyArray array = context.runtime.newArray();
        
        for (int i = 0; i < keys.length; i++) {
            array.append(aref(context, keys[i]));
        }
        
        return array;
    }
    
    @JRubyMethod(name = {"length", "size"})
    public IRubyObject length(ThreadContext context) {
        ensureDBOpen(context);
        return context.runtime.newFixnum(map.size());
    }
    
    @JRubyMethod(name = "empty?")
    public IRubyObject empty_p(ThreadContext context) {
        ensureDBOpen(context);
        return context.runtime.newBoolean(map.isEmpty());
    }

    @JRubyMethod(name = {"each", "each_pair"})
    public IRubyObject each(ThreadContext context, Block block) {
        ensureDBOpen(context);
        if (!block.isGiven()) return RubyEnumerator.enumeratorize(context.runtime, this, "each");
        
        for (String key: map.keySet()) {
            block.yieldSpecific(context, rstr(context, key), rstr(context, map.get(key)));
        }
        
        return this;
    } 

    @JRubyMethod
    public IRubyObject each_value(ThreadContext context, Block block) {
        ensureDBOpen(context);
        if (!block.isGiven()) return RubyEnumerator.enumeratorize(context.runtime, this, "each_value");
        
        for (String key: map.keySet()) {
            block.yieldSpecific(context, rstr(context, map.get(key)));
        }
        
        return this;
    } 

    @JRubyMethod
    public IRubyObject each_key(ThreadContext context, Block block) {
        ensureDBOpen(context);
        if (!block.isGiven()) return RubyEnumerator.enumeratorize(context.runtime, this, "each_key");
        
        for (String key: map.keySet()) {
            block.yieldSpecific(context, rstr(context, key));
        }
        
        return this;
    }
    
    @JRubyMethod
    public IRubyObject keys(ThreadContext context, Block block) {
        ensureDBOpen(context);
        RubyArray array = context.runtime.newArray();
        
        for (String key : map.keySet()) {
            array.append(rstr(context, key));
        }
        
        return array;
    }
    
    @JRubyMethod
    public IRubyObject values(ThreadContext context, Block block) {
        ensureDBOpen(context);
        RubyArray array = context.runtime.newArray();
        
        for (String key : map.keySet()) {
            array.append(rstr(context, map.get(key)));
        }
        
        return array;
    }
    
    @JRubyMethod
    public IRubyObject shift(ThreadContext context) {
        ensureDBOpen(context);
        ensureNotFrozen(context);
        
        Entry<String, String> pair = map.firstEntry();
        
        if (pair == null) return context.runtime.getNil();
        
        remove(context, pair.getKey());
        db.commit();

        return context.runtime.newArray(rstr(context, pair.getKey()), rstr(context, pair.getValue()));
    }
    
    @JRubyMethod
    public IRubyObject delete(ThreadContext context, IRubyObject key, Block block) {
        ensureDBOpen(context);
        ensureNotFrozen(context);
        
        String value = map.get(str(context, key));
        
        if (value == null) return block.isGiven() ? block.yieldSpecific(context, key) : context.runtime.getNil();
        
        remove(context, str(context, key));
        db.commit();

        return rstr(context, value);
    }
    
    @JRubyMethod(name = {"delete_if", "reject!"})
    public IRubyObject delete_if(ThreadContext context, Block block) {
        ensureDBOpen(context);
        ensureNotFrozen(context);
        
        for (String key : map.keySet()) {
            IRubyObject rkey = rstr(context, key);
            IRubyObject rvalue = rstr(context, map.get(key));
            
            if (block.yieldSpecific(context, rkey, rvalue).isTrue()) remove(context, key);
        }
        db.commit();
        
        return this;
    }
    
    @JRubyMethod
    public IRubyObject reject(ThreadContext context, Block block) {
        return to_hash(context).callMethod(context, "delete_if", NULL_ARRAY, block);
    }
    
    @JRubyMethod
    public IRubyObject clear(ThreadContext context) {
        ensureDBOpen(context);
        ensureNotFrozen(context);
        
        map.clear();
        db.commit();
        
        return this;
    }
    
    @JRubyMethod
    public IRubyObject invert(ThreadContext context) {
        ensureDBOpen(context);
        RubyHash hash = RubyHash.newHash(context.runtime);
        
        for (String key : map.keySet()) {
            hash.fastASet(rstr(context, map.get(key)), rstr(context, key));
        }        
        
        return hash;
    }
    
    @JRubyMethod(name = {"has_key?", "key?", "include?", "member?"})
    public IRubyObject has_key(ThreadContext context, IRubyObject value) {
        ensureDBOpen(context);
        return context.runtime.newBoolean(map.get(str(context, value)) != null);
    }

    @JRubyMethod(name = {"value?", "has_value?"})
    public IRubyObject has_value(ThreadContext context, IRubyObject testArg) {
        ensureDBOpen(context);
        String test = str(context, testArg);
        
        for (String value: map.values()) {
            if (test.equals(value)) return context.runtime.getTrue();
        }
        
        return context.runtime.getFalse();
    }
    
    @JRubyMethod
    public IRubyObject to_a(ThreadContext context) {
        ensureDBOpen(context);
        RubyArray array = context.runtime.newArray();
        
        for (String key: map.keySet()) {
            array.append(context.runtime.newArray(rstr(context, key), rstr(context, map.get(key))));
        }
        
        return array;
    }
    
    @JRubyMethod
    public IRubyObject to_hash(ThreadContext context) {
        ensureDBOpen(context);
        RubyHash hash = RubyHash.newHash(context.runtime);
        
        for (String key: map.keySet()) {
            hash.fastASet(rstr(context, key), rstr(context, map.get(key)));
        }
        
        return hash;
    }
    
    private String remove(ThreadContext context, String key) {
        try {
            return map.remove(key);
        } catch (UnsupportedOperationException e) {
            dbError(context, "dbm_store failed");
        }
        
        return null; // Not reached
    }
    
    private void store(ThreadContext context, IRubyObject key, IRubyObject value) {
        try {
            map.put(str(context, key), str(context, value));
        } catch (UnsupportedOperationException e) {
            dbError(context, "dbm_store failed");
        }        
    }
    
    private void ensureDBOpen(ThreadContext context) {
        if (map == null) dbError(context, "closed DBM file");
    }
    
    private void ensureNotFrozen(ThreadContext context) {
        if (isFrozen()) throw context.runtime.newFrozenError("DBM");
    }

    private void dbError(ThreadContext context, String message) {
        throw new RaiseException(context.runtime, context.runtime.getClass("DBMError"), message, true);
    }
    
    private String str(ThreadContext context, IRubyObject value) {
        return RubyString.objAsString(context, value).asJavaString();  
    }

    private IRubyObject rstr(ThreadContext context, String value) {
        return context.runtime.newString(value);  
    }
    
    private boolean isReadOnly() {
        return db.getEngine().isReadOnly();
    }

    private void truncate(File file) {
        try {
            FileChannel channel = new FileOutputStream(file, true).getChannel();
            channel.truncate(0);
            channel.close();
        } catch (FileNotFoundException e) {
        } catch (IOException e) {
        }
    }
}
